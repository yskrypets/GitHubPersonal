public with sharing class FilesActionsBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful{
    public final String query; public final String value; public final String token;
    
    public FilesActionsBatch(String value, String token) {
        this.value = value;   this.token = token;
        query = 'SELECT id FROM ContentDocument WHERE ContentSize < 4194304';
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        if(!Schema.sObjectType.ContentDocument.isAccessible()) return null;
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        Set<id> docIds = new Set<id>();
        for(Sobject s : scope) {
            docIds.add((id) s.get('id'));
        }
        
        List<Object> filesForDelete = copyFiles(docIds, token);

        if(value.equalsIgnoreCase('move') && Schema.sObjectType.ContentDocument.isDeletable()) {
            List<ContentDocument> filtered = new List<ContentDocument>();
            for(Object obj : filesForDelete) {
                Map<String, Object> fileMap = (Map<String, Object>) obj;
                for(sObject sobj : scope) {
                    if((id) sobj.get('id') == (id) fileMap.get('sfId')) filtered.add((ContentDocument) sobj);
                }
            }
            if(!Test.isRunningTest()) {
                if(Schema.sObjectType.ContentDocument.isDeletable()) {
                    delete filtered;
                }
            }
        }
    }
    
    public void finish(Database.BatchableContext BC){
        try {
        	Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        	message.toAddresses = new String[] { UserInfo.getUserEmail() };
        	message.subject = 'FileLink';
        	message.plainTextBody = 'Your request to ' + value + ' files to Google Drive is complete.';
        	Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
        	Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
        } catch(Exception e) {
            system.debug(e.getMessage());
        }
    }
    
    
    private static List<Object> copyFiles(Set<id> docIds, String token) {
        List<Object> filesForDelete = new List<Object>(); Map<Id, Object> recordIdToFilesList = new Map<Id, Object>();
        
        if(Schema.sObjectType.ContentVersion.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.ContentDocumentId.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.VersionData.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.IsLatest.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.FileType.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.Title.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.FileExtension.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.ContentSize.isAccessible()) {
               for(ContentVersion cv : [SELECT ContentDocumentId, VersionData, IsLatest, FileType, Title, FileExtension, ContentSize FROM ContentVersion WHERE ContentDocumentId IN: docIds AND ContentSize <= 6291456]) {
                   if(cv.IsLatest) {
                       Map<String, Object> fileMap = new Map<String, Object>();
                       fileMap.put('name', cv.Title + '.' + cv.FileExtension);
                       fileMap.put('type', convertMimeType(cv.FileExtension));
                       fileMap.put('content', cv.VersionData);
                       fileMap.put('byteSize', cv.ContentSize);
                       fileMap.put('size', returnFileSize(cv.ContentSize));
                       fileMap.put('sfId', cv.ContentDocumentId);
                       recordIdToFilesList.put(cv.ContentDocumentId, fileMap);
                   }
               }
        }
        
        if(Schema.sObjectType.ContentDocumentLink.isAccessible() &&
           Schema.sObjectType.ContentDocumentLink.Fields.ContentDocumentId.isAccessible() &&
           Schema.sObjectType.ContentDocumentLink.Fields.LinkedEntityId.isAccessible() &&
           Schema.sObjectType.ContentDocumentLink.Fields.ShareType.isAccessible()) {
               for(ContentDocumentLink cdl : [SELECT ContentDocumentId, LinkedEntityId, ShareType FROM ContentDocumentLink WHERE ContentDocumentId IN: docIds]) {
                   if(cdl.ShareType.equals('V')) {
                       Map<String, Object> fileMap = (Map<String, Object>) recordIdToFilesList.get(cdl.ContentDocumentId);
                       List<Object> filesList = recordIdToFilesList.containsKey(cdl.LinkedEntityId) ? (List<Object>) recordIdToFilesList.get(cdl.LinkedEntityId) : new List<Object>();
                       filesList.add(fileMap);
                       recordIdToFilesList.put(cdl.LinkedEntityId, filesList);
                       recordIdToFilesList.remove(cdl.ContentDocumentId);
                   }
               }
           }
        
        Set<String> setNames = new Set<String>();
        for(String recId : recordIdToFilesList.keySet()) {
            if(recId.startsWith('069')) {
                recordIdToFilesList.remove(recId);
            } else {
                id recordId = recId;
                setNames.add(recordId.getSobjectType().getDescribe().getName());
            }
        }
        List<Drive_Object__c> dobList = new List<Drive_Object__c>();
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.isCreated__c.isAccessible()) {
               dobList = [SELECT Name FROM Drive_Object__c WHERE Name IN: setNames AND isCreated__c = true];
           }
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
                    } catch(Exception e) {
                        System.debug(e);
                    }
                }
                if(!Test.isRunningTest()) FilesController.updateLog(JSON.serialize(uploadedFiles), 'Add file', recId, recordFolderId);
                filesForDelete.addAll(uploadedFiles);
            }
        }
        
        return filesForDelete;
    }
    
    
    public static void uploadFile(Map<String, Object> fileMap, String recordFolderId, id recordId, String token) {
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
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*2000);

        Http h = new Http();
        
        if(!Test.isRunningTest()) {
            HttpResponse res = h.send(req);
            system.debug(res.getBody());
        }
    }
    
    
    public static String convertMimeType(String input) {
        Map<String, String> mimeTypes = new Map<String, String>();
        mimeTypes.put('xls', 'application/vnd.ms-excel');        mimeTypes.put('xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');        mimeTypes.put('xml', 'text/xml');        mimeTypes.put('ods', 'application/vnd.oasis.opendocument.spreadsheet');        mimeTypes.put('csv', 'text/plain');        mimeTypes.put('tmpl', 'text/plain');        mimeTypes.put('pdf', 'application/pdf');        mimeTypes.put('php', 'application/x-httpd-php');        mimeTypes.put('jpg', 'image/jpeg');        mimeTypes.put('png', 'image/png');
        mimeTypes.put('gif', 'image/gif');        mimeTypes.put('bmp', 'image/bmp');        mimeTypes.put('txt', 'text/plain');        mimeTypes.put('doc', 'application/msword');        mimeTypes.put('docx', 'application/msword');        mimeTypes.put('js', 'text/js');        mimeTypes.put('swf', 'application/x-shockwave-flash');        mimeTypes.put('mp3', 'audio/mpeg');        mimeTypes.put('zip', 'application/zip');        mimeTypes.put('rar', 'application/rar');        mimeTypes.put('tar', 'application/tar');        mimeTypes.put('arj', 'application/arj');        mimeTypes.put('cab', 'application/cab');        mimeTypes.put('html', 'text/html');        mimeTypes.put('htm', 'text/html');
        mimeTypes.put('default', 'application/octet-stream');
        return mimeTypes.containsKey(input) ? mimeTypes.get(input) : mimeTypes.get('default');
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