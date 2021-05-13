public with sharing class ClearDeletedIterable implements Database.Batchable<Object>, Database.AllowsCallouts, Database.Stateful {
    public List<Object> foldersList {get;set;}
    private static final String mainFolderName = 'Salesforce Root';
    private String mainFolderId {get;set;}
    private String archivedFolderId {get;set;}
    private String removedRecordsFolderId {get;set;}
    private String token {get;set;}
    
    public ClearDeletedIterable(String token) {
        this.token = token;  
        mainFolderId = getFolderId(mainFolderName, null);  
        archivedFolderId = getFolderId('Archived', mainFolderId);  
        removedRecordsFolderId = getFolderId('Removed Records', archivedFolderId);
        if(removedRecordsFolderId == null) removedRecordsFolderId = FilesController.CreateSubFolder('Removed Records', archivedFolderId, token, false);
        foldersList = getRecordsFolders(null, removedRecordsFolderId, token);
        system.debug(foldersList);
        //system.debug(mainFolderId);
        //system.debug(archivedFolderId);
        system.debug(removedRecordsFolderId);
    }
    
    public Iterable<Object> start(Database.BatchableContext BC) {
        return this.foldersList; 
    }     
    
    public void execute(Database.BatchableContext BC, List<Object> scope) {
        Set<String> recordsForRemove = new Set<String>(); 
        Map<String, Set<String>> sobjToIds = createObjectsMap(scope);
        for(String objName : sobjToIds.keySet()) {
            system.debug(objName);
            Set<String> tmp = sobjToIds.get(objName);
            List<sObject> sfList = new List<sObject>();
            if(Schema.getGlobalDescribe().get(objName).getDescribe().isAccessible())
                sfList = Database.query('SELECT id FROM ' + objName + ' WHERE id IN: tmp');
            system.debug(sfList);
            for(sObject sfObj : sfList) {
                if(tmp.contains((String) sfObj.get('id'))) {
                    tmp.remove((String)sfObj.get('id'));
                }
            }
            if(!tmp.isEmpty()) recordsForRemove.addAll(tmp);
            system.debug(recordsForRemove);
        }

        for(String recordId : recordsForRemove) {
            List<Object> folderObj = getRecordsFolders(recordId, removedRecordsFolderId, token);
            system.debug(folderObj);
            for(Object fld : folderObj) {
                Map<String, Object> fldMap = (Map<String, Object>) fld;
                Drive__c drive = Drive__c.getOrgDefaults();
                switch on drive.External_Drive_Name__c {
                    when 'gdrive' {
                        for(Object obj : (List<Object>) fldMap.get('parents')) {
                            Map<String, Object> parentObj = (Map<String, Object>) obj;
                            system.debug(parentObj);
                            FoldersListController.moveFolder((String) fldMap.get('id'), removedRecordsFolderId, (String) parentObj.get('id'), this.token);
                        }
                    }
                    when 'onedrive' {
                        FoldersListController.moveFolder((String) fldMap.get('id'), removedRecordsFolderId, null, this.token);
                    }
                }
            }
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        system.debug('Finish Iteration');
    }
    
    
    
    
    private Map<String, Set<String>> createObjectsMap(List<Object> scope) { //Create Map sObject name to set of ids
        Drive__c drive = Drive__c.getOrgDefaults();
        Map<String, Set<String>> sobjToIds = new Map<String, Set<String>>();
        for(Object obj : scope) {
            Map<String, Object> objMap = (Map<String, Object>) obj;
            for(String key : objMap.keySet()) {
                system.debug(key + ' - ' + objMap.get(key));
            }
            Id objId;
            switch on drive.External_Drive_Name__c {
                when 'gdrive' {
                    objId = (String) objMap.get('description');
                }
                when 'onedrive' {
                    objId = ((String) objMap.get('name')).substringAfter(' (').substringBefore(')');
                }
            }
            String sobjName = objId.getSobjectType().getDescribe().getName();
            Set<String> recordIds = new Set<String>();
            if(sobjToIds.containsKey(sobjName)) {
                recordIds = sobjToIds.get(sobjName);
            }
            recordIds.add(objId);
            sobjToIds.put(sobjName, recordIds);
        }
        return sobjToIds;
    }
    
    
    
    
    private List<Object> getRecordsFolders(String recordId, String removedRecordsFolderId, String token) { //Get all records folders
        Drive__c drive = Drive__c.getOrgDefaults();
        String endPoint;
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                String properties = recordId == null ? 'properties%20has%20%7B%20key%3D%27isRecord%27%20and%20value%3D%27True%27%20and%20visibility%3D%27PUBLIC%27%20%7D' : 'properties%20has%20%7B%20key%3D%27recordId%27%20and%20value%3D%27' + recordId + '%27%20and%20visibility%3D%27PUBLIC%27%20%7D';
                endPoint = 'https://content.googleapis.com/drive/v2/files?q=' + properties + '%20and%20trashed%3Dfalse%20and%20not%20%27' + removedRecordsFolderId + '%27%20in%20parents';
            }
            when 'onedrive' {
                String queryString = recordId == null ? '%20(' : recordId;
                endPoint = 'https://graph.microsoft.com/v1.0/me/drive/root/search(q=\'' + queryString + '\')?select=name,id,parentReference';
            }
        }
        system.debug(endPoint);
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endPoint);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'application/*');
        req.setTimeout(60*1000);
        
        Http h = new Http();  HttpResponse res = h.send(req);
        String resp = res.getBody();
        system.debug(resp);

        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        if(respMap.containsKey('items')) {
            List<Object> folders = (List<Object>) respMap.get('items');
            if(!folders.isEmpty()) {
                return folders;
            }
        } else if(respMap.containsKey('value')) {
            List<Object> folders = (List<Object>) respMap.get('value');
            List<Object> foldersForReturn = new List<Object>();
            if(!folders.isEmpty()) {
                for(Object obj : folders) {
                    Map<String, Object> fld = (Map<String, Object>) obj;
                    if(((String) fld.get('name')).contains(' (')) {
                        foldersForReturn.add(obj);
                    }
                }
                return foldersForReturn;
            }
        }
        return new List<Object>();
    }
    
    
    
    private String getFolderId(String folderName, String parentFolderId) { //Get folder id from Google Drive by name and parent folder id
        HttpRequest req = new HttpRequest();
        Drive__c drive = Drive__c.getOrgDefaults();
        String endPoint;
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                String parentId = parentFolderId != null ? ('%20and%20%27' + parentFolderId + '%27%20in%20parents') : '';
                endPoint = 'https://content.googleapis.com/drive/v3/files?q=mimeType%3D%27application%2Fvnd.google-apps.folder%27%20and%20name=%27' + folderName.replaceAll(' ', '%20') + '%27%20and%20trashed%3Dfalse' + parentId;
            }
            when 'onedrive' {
                endPoint = 'https://graph.microsoft.com/v1.0/me/drive/root/search(q=\'' + folderName.replaceAll(' ', '%20') + '\')?select=name,id';
                req.setHeader('Accept', 'application/*');
            }
        }
        req.setMethod('GET');
        req.setEndpoint(endPoint);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*1000);

        Http h = new Http();  HttpResponse res = h.send(req);
        String resp = res.getBody();
        system.debug(resp);

        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        if(respMap.containsKey('files')) {
            List<Object> files = (List<Object>) respMap.get('files');
            if(!files.isEmpty()) {
                Map<String, Object> file = (Map<String, Object>) files.get(0);
                return (String) file.get('id');
            }
        } else if(respMap.containsKey('value')) {
            List<Object> files = (List<Object>) respMap.get('value');
            if(!files.isEmpty()) {
                for(Object obj : files) {
                	Map<String, Object> file = (Map<String, Object>) obj;
                    system.debug(folderName + ' - ' + file.get('name'));
                	if((String) file.get('name') == folderName) return (String) file.get('id');
                }
            }
        }
        return null;
    }
}