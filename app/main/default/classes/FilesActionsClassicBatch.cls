public with sharing class FilesActionsClassicBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful{
    public final String query;
    public final String value;
    public final String token;
    
    public FilesActionsClassicBatch(String value, String token) {
        this.value = value;
        this.token = token;
        query = 'SELECT id, Name, Body, ParentId, ContentType, BodyLength FROM Attachment WHERE BodyLength < 4194304';
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        if(!Schema.sObjectType.Attachment.isAccessible() &&
           Schema.sObjectType.Attachment.Fields.Name.isAccessible() &&
           Schema.sObjectType.Attachment.Fields.Body.isAccessible() &&
           Schema.sObjectType.Attachment.Fields.ParentId.isAccessible() &&
           Schema.sObjectType.Attachment.Fields.ContentType.isAccessible() &&
           Schema.sObjectType.Attachment.Fields.BodyLength.isAccessible()) {
               return null;               
           }
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        try {
            List<Object> filesForDelete = copyFiles(scope, token);
            
            if(value.equalsIgnoreCase('move') && !filesForDelete.isEmpty() && Schema.sObjectType.ContentDocument.isDeletable()) {
                List<Attachment> forDelete = new List<Attachment>();
                for(Object obj : filesForDelete) {
                    Map<String, Object> fileMap = (Map<String, Object>) obj;
                    forDelete.add(new Attachment(id=(String) fileMap.get('sfId')));
                }
                if(!Test.isRunningTest()) {
                    if(Schema.sObjectType.Attachment.isDeletable()) {
                        delete forDelete;
                    }
                }
            }
        } catch(Exception e) {
            system.debug(e);
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        try {
            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.toAddresses = new String[] { UserInfo.getUserEmail() };
            message.subject = 'FileLink';
            message.plainTextBody = 'Your request to ' + value + ' attachments to Google Drive is complete.';
            Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
            if(!Test.isRunningTest()) Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
        } catch(Exception e) {
            system.debug(e.getMessage());
        }
    }
    
    
    private static List<Object> copyFiles(List<sObject> scope, String token) {
        List<Object> filesForDelete = new List<Object>();
        Map<String, List<Object>> recordIdToFilesList = new Map<String, List<Object>>();
        
        for(sObject so : scope) {
            Map<String, Object> fileMap = new Map<String, Object>();
            fileMap.put('name', so.get('Name'));
            fileMap.put('type', so.get('ContentType'));
            fileMap.put('content', so.get('Body'));
            fileMap.put('byteSize', (Long) so.get('BodyLength'));
            fileMap.put('size', returnFileSize((Decimal) so.get('BodyLength')));
            fileMap.put('sfId', so.get('Id'));
            List<Object> newFiles = new List<Object>();
            if(recordIdToFilesList.containsKey((String) so.get('ParentId'))) newFiles = recordIdToFilesList.get((String) so.get('ParentId'));
            newFiles.add(fileMap);
            recordIdToFilesList.put((String) so.get('ParentId'), newFiles);
        }
        
        Set<String> setNames = new Set<String>();
        for(String recId : recordIdToFilesList.keySet()) {
            id recordId = recId;
            setNames.add(recordId.getSobjectType().getDescribe().getName());
        }
        List<Drive_Object__c> dobList = new List<Drive_Object__c>();
        if(Schema.sObjectType.Drive_Object__c.isAccessible() &&
           Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() &&
           Schema.sObjectType.Drive_Object__c.Fields.isCreated__c.isAccessible()) {
               dobList = [SELECT Name FROM Drive_Object__c WHERE Name IN: setNames AND isCreated__c = true];
           }
        setNames = new Set<String>();
        for(Drive_Object__c dob : dobList) {
            setNames.add(dob.Name);
        }

        for(String recId : recordIdToFilesList.keySet()) {
            id recordId = recId;
            if(setNames.contains(recordId.getSobjectType().getDescribe().getName())) {
                Map<String, Object> recordMap = Test.isRunningTest() ? (Map<String, Object>) JSON.deserializeUntyped('{"folderId":"folderIdTest"}') : (Map<String, Object>) JSON.deserializeUntyped(FilesController.createRecordFolder(recordId));
                String recordFolderId = (String) recordMap.get('folderId');
                
                List<Object> uploadedFiles = new List<Object>();
                for(Object obj : (List<Object>) recordIdToFilesList.get(recId)) {
                    Map<String, Object> fileMap = (Map<String, Object>) obj;
                    try {
                        uploadFile(fileMap, recordFolderId, recordId, token);
                        uploadedFiles.add(fileMap);
                    } catch(Exception e) {System.debug(e);}
                }
                if(!Test.isRunningTest()) FilesController.updateLog(JSON.serialize(uploadedFiles), 'Add file', recId, recordFolderId);
                filesForDelete.addAll(uploadedFiles);
            }
        }
        
        return filesForDelete;
    }
    
    
    public static void uploadFile(Map<String, Object> fileMap, String recordFolderId, id recordId, String token) {
        system.debug(fileMap);
        system.debug(recordFolderId + ' - ' + recordId);
        HttpRequest req = new HttpRequest();
        Drive__c drive = Drive__c.getOrgDefaults();
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                String boundary = 'googleProject';
                String delimiter = '\r\n--' + boundary + '\r\n';
                String close_delim = '\r\n--' + boundary + '--';
                
                Map<String, Object> metadata = new Map<String, Object>();
                metadata.put('name', (String)fileMap.get('name'));
                metadata.put('parents', new List<Object>{recordFolderId});
                metadata.put('properties', new Map<String, Object>{'parentId'=>recordId,'subfolder'=>''});
                
                String multipartRequestBody = delimiter +
                    'Content-Type: application/json\r\n\r\n' +
                    JSON.serialize(metadata) + delimiter +
                    'Content-Type: ' + (String)fileMap.get('type') + '\r\n' +
                    'Content-Transfer-Encoding: base64\r\n' +
                    '\r\n' + EncodingUtil.base64Encode((Blob)fileMap.get('content')) + close_delim;
                
                req.setMethod('POST');
        		req.setEndpoint('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart');
                req.setHeader('Content-Type', 'multipart/mixed; boundary="' + boundary + '"');
        		req.setHeader('Content-Length', String.valueOf(multipartRequestBody.length()));
        		req.setBody(multipartRequestBody);
            }
            when 'onedrive' {
                req.setMethod('PUT');
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + recordFolderId + ':/' + ((String)fileMap.get('name')).replaceAll(' ', '%20') + ':/content');
                req.setHeader('Content-Type', 'application/octet-stream');
                req.setHeader('Accept', 'application/*');
                req.setBodyAsBlob((Blob)fileMap.get('content'));
            }
        }
        system.debug(req.getEndpoint());
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*2000);
        
        Http h = new Http();
        
        if(!Test.isRunningTest()) {
            HttpResponse res = h.send(req);
            system.debug(res);
        }
    }
    
    
    public static String returnFileSize(Decimal num) {
        if(num < 1024) {
            return num + ' bytes';
        } else if(num > 1024 && num < 1048576) {
            return (num/1024).setScale(1) + ' KB';
        } else if(num > 1048576) {
            return (num/1048576).setScale(1) + ' MB';
        }
        return '' + num;
    }
}