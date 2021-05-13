public with sharing class ClassicFilesTriggerHandler {
    @future(callout=true)
    public static void checkAction(String triggerJSON) {
        String action = Drive__c.getOrgDefaults().Files_Action__c;
        if(action != null && action != 'nothing') {
            Map<String, Object> auth = Test.isRunningTest() ? (Map<String, Object>) JSON.deserializeUntyped('{"auth":true}') : (Map<String, Object>) AuthController.checkAuthorizing();
            String token = !Test.isRunningTest() ? AuthController.CheckTokenAvailability() : null;
            if(token == null) token = AuthController.getAccessToken();
            
            if((Boolean) auth.get('auth')) {
                List<Object> attList = (List<Object>) JSON.deserializeUntyped(triggerJSON);
                
                List<Object> filesForDelete = copyFiles(attList, token);                                              
                
                if(Drive__c.getOrgDefaults().Files_Action__c.equalsIgnoreCase('move') && !filesForDelete.isEmpty() &&
                   Schema.sObjectType.Attachment.isDeletable()) {
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
            }
        }
    }
    
    
    
    private static List<Object> copyFiles(List<Object> attList, String token) {
        Set<id> attIds = new Set<id>();
        for(Object obj : attList) {
            Map<String, Object> att = (Map<String, Object>) obj;
            attIds.add((id) att.get('Id'));
        }

        if(Schema.sObjectType.Attachment.isAccessible() &&
           Schema.sObjectType.Attachment.Fields.Body.isAccessible()) {
               Map<id, Attachment> attMap = new Map<id, Attachment>([SELECT id, Body FROM Attachment WHERE id IN: attIds]);
               
               for(Object obj : attList) {
                   Map<String, Object> att = (Map<String, Object>) obj;
                   att.put('Body', attMap.get((id) att.get('Id')).Body);
               }              
           }
        
        List<Object> filesForDelete = new List<Object>();
        Map<String, List<Object>> recordIdToFilesList = new Map<String, List<Object>>();
     
        
        for(Object obj : attList) {
            Map<String, Object> att = (Map<String, Object>) obj;
            Map<String, Object> fileMap = new Map<String, Object>();
            fileMap.put('name', att.get('Name'));
            fileMap.put('type', att.get('ContentType'));
            fileMap.put('content', att.get('Body'));
            fileMap.put('byteSize', att.get('BodyLength'));
            fileMap.put('size', FilesActionsClassicBatch.returnFileSize((Decimal) att.get('BodyLength')));
            fileMap.put('sfId', att.get('Id'));
            List<Object> newFiles = new List<Object>(); 
            if(recordIdToFilesList.containsKey((String) att.get('ParentId'))) newFiles = recordIdToFilesList.get((String) att.get('ParentId'));
            newFiles.add(fileMap);
            recordIdToFilesList.put((String) att.get('ParentId'), newFiles);
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
                        System.debug(fileMap);
                        FilesActionsClassicBatch.uploadFile(fileMap, recordFolderId, recordId, token);
                        uploadedFiles.add(fileMap);
                        
                    } catch(Exception e) {System.debug(e);}
                }
                 
                if(!Test.isRunningTest()) FilesController.updateLog(JSON.serialize(uploadedFiles), 'Add file', recId, recordFolderId);
                filesForDelete.addAll(uploadedFiles);
            }
        }
      
        return filesForDelete;
    }
}