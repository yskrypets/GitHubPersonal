public with sharing class LightningFilesTriggerHandler {
    @future(callout=true)
    public static void checkAction(String triggerJSON) {
        String token = !Test.isRunningTest() ? AuthController.CheckTokenAvailability() : null;
        if(token == null) {
            token = AuthController.getAccessToken();
        }
        
        if(Schema.sObjectType.ContentVersion.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.ContentDocumentId.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.VersionData.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.IsLatest.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.FileType.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.Title.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.FileExtension.isAccessible() &&
           Schema.sObjectType.ContentVersion.Fields.ContentSize.isAccessible()) {
            List<ContentVersion> cvList = [SELECT ContentDocumentId, VersionData, IsLatest, FileType, Title, FileExtension, ContentSize FROM ContentVersion WHERE Id IN: (Set<Id>) JSON.deserialize(triggerJSON, Set<Id>.class) AND ContentSize <= 6291456];
            
            List<Object> filesForDelete = new List<Object>();
            
            for(ContentVersion cv : cvList) {
                filesForDelete.addAll(copyFile(cv, token));
            }
            
            if(Drive__c.getOrgDefaults().Files_Action__c.equalsIgnoreCase('move') && !filesForDelete.isEmpty() && Schema.sObjectType.ContentDocument.isDeletable()) {
                List<ContentDocument> filtered = new List<ContentDocument>();
                for(Object obj : filesForDelete) {
                    Map<String, Object> fileMap = (Map<String, Object>) obj;
                    for(ContentVersion cv : cvList) {
                        if(cv.id == (id) fileMap.get('sfId')) filtered.add(new ContentDocument(id=cv.ContentDocumentId));
                    }
                }
                if(Schema.sObjectType.ContentDocument.isDeletable()) {
                    delete filtered;
                }
            }
        }
    }
    
    
    
    public static List<Object> copyFile(ContentVersion cv, String token) {
        List<Object> filesForDelete = new List<Object>();
        Map<Id, Object> recordIdToFilesList = new Map<Id, Object>();
        
        Map<String, Object> verMap = new Map<String, Object>();
        verMap.put('name', cv.Title + '.' + cv.FileExtension);
        verMap.put('type', FilesActionsBatch.convertMimeType(cv.FileExtension));
        verMap.put('content', cv.VersionData);
        verMap.put('size', FilesActionsBatch.returnFileSize(cv.ContentSize));
        verMap.put('sfId', cv.ContentDocumentId);
        recordIdToFilesList.put(cv.ContentDocumentId, verMap);
        
        if(Schema.sObjectType.ContentDocumentLink.isAccessible() &&
           Schema.sObjectType.ContentDocumentLink.Fields.ContentDocumentId.isAccessible() &&
           Schema.sObjectType.ContentDocumentLink.Fields.LinkedEntityId.isAccessible() &&
           Schema.sObjectType.ContentDocumentLink.Fields.ShareType.isAccessible()) {
               for(ContentDocumentLink cdl : [SELECT ContentDocumentId, LinkedEntityId, ShareType FROM ContentDocumentLink WHERE ContentDocumentId =: cv.ContentDocumentId]) {
                   if(cdl.ShareType.equals('V')) {
                       Map<String, Object> linkMap = (Map<String, Object>) recordIdToFilesList.get(cdl.ContentDocumentId);
                       List<Object> filesList = recordIdToFilesList.containsKey(cdl.LinkedEntityId) ? (List<Object>) recordIdToFilesList.get(cdl.LinkedEntityId) : new List<Object>();
                       filesList.add(linkMap);
                       recordIdToFilesList.put(cdl.LinkedEntityId, filesList);
                       recordIdToFilesList.remove(cdl.ContentDocumentId);
                   }
               }
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
                        if(!Test.isRunningTest()) FilesActionsBatch.uploadFile(fileMap, recordFolderId, recordId, token);
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