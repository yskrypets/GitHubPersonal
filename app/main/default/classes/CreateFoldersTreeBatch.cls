public with sharing class CreateFoldersTreeBatch implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful {
    public List<String> objNames {get;set;}
    public Map<String, String> objects {get;set;}
    private String token {get;set;}
    private static final String mainFolderName = 'Salesforce Root';
    private String mainFolderId {get;set;}
    
    public CreateFoldersTreeBatch() {
        objNames = new List<String>();
    }
    
    public Iterable<String> start(Database.BatchableContext BC) {
        if(checkIfExists()) {
            return new List<String>();
        } else {
            createBaseFolders();
            objects = getObjectsList();
            objNames.addAll(objects.keySet());
        }
        return this.objNames; 
    }
    
    public void execute(Database.BatchableContext BC, List<String> scope) {
        for(String s : scope) {
            AuthController.CreateSubFolder(s, objects.get(s), mainFolderId, token);
        }
    }
    
    public void finish(Database.BatchableContext BC){}
    
    private void createBaseFolders() {
        HttpRequest req = new HttpRequest();
        Drive__c drive = Drive__c.getOrgDefaults();
        String endPoint;
        token = AuthController.getAccessToken();
        Map<String, Object> bodyMap = new Map<String, Object>();
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                endPoint = 'https://content.googleapis.com/drive/v2/files';
                bodyMap.put('title', mainFolderName);
        		bodyMap.put('mimeType', 'application/vnd.google-apps.folder');
            }
            when 'onedrive' {
                endPoint = 'https://graph.microsoft.com/v1.0/me/drive/root/children';
                req.setHeader('Accept', 'application/*');
                bodyMap.put('name', mainFolderName);
        		bodyMap.put('folder', new Map<String, Object>());
            }
        }
        
        String body = JSON.serialize(bodyMap);
        
        req.setMethod('POST');
        req.setEndpoint(endPoint);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('content-type', 'application/json');
        req.setHeader('Content-length', String.valueOf(body.length()));
        req.setBody(body);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
        system.debug(resp);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        mainFolderId = (String) respMap.get('id');
        
        AuthController.setRootPermissions(mainFolderId, token);
        
        String archivedFolderId = AuthController.CreateSubFolder('Archived', 'Archived', mainFolderId, token);
        AuthController.CreateSubFolder('Removed Records', 'Removed Records', archivedFolderId, token);
        AuthController.CreateSubFolder('Removed Files', 'Removed Files', archivedFolderId, token);
    }
    
    
    private static Boolean checkIfExists() { //Check if Salesforce Root folder already created on Google Drive
        Drive__c drive = Drive__c.getOrgDefaults();
        String endPoint;
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                endPoint = 'https://content.googleapis.com/drive/v3/files?q=mimeType%3D%27application%2Fvnd.google-apps.folder%27%20and%20name%3D%27' + mainFolderName.replaceAll(' ', '%20') + '%27%20and%20trashed%3Dfalse';
            }
            when 'onedrive' {
                endPoint = 'https://graph.microsoft.com/v1.0/me/drive/root/search(q=\'' + mainFolderName.replaceAll(' ', '%20') + '\')?select=name,id';
            }
        }
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endPoint);
        req.setHeader('Authorization', 'Bearer ' + AuthController.getAccessToken());
        req.setHeader('Accept', 'application/*');
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
        system.debug(resp);
        
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        if(respMap.containsKey('files')) {
            List<Object> files = (List<Object>) respMap.get('files');
            if(files.isEmpty()) return false;
        } else if(respMap.containsKey('value')) {
            List<Object> values = (List<Object>) respMap.get('value');
            if(values.isEmpty()) return false;
        }
        return true;
    }
    
    
    private static Map<String, String> getObjectsList() { //Get list of salesforce objects
        Map<String, Schema.SObjectType> forSeparate = getAllObjects();
        Map<String, String> obj = new Map<String, String>();
        
        Map<String, Schema.SObjectType> separated = separateParentsChilds(forSeparate);
        for(String objName : separated.keySet()) {
            Schema.DescribeSObjectResult dor = separated.get(objName).getDescribe();
            obj.put(dor.getName(), dor.getLabel());
            if(Test.isRunningTest()) return obj;
        }
        
        return obj;
    }
    
    
    public static Map<String, Schema.SObjectType> getAllObjects() {
        Set<String> doChecked = new Set<String>();
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && 
           Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() && 
           Schema.sObjectType.Drive_Object__c.Fields.isCreated__c.isAccessible()) {
            for(Drive_Object__c dobj : [SELECT id, Name FROM Drive_Object__c WHERE isCreated__c = true]) {
                doChecked.add(dobj.Name.toLowerCase());
            }
        }
        Map<String, Schema.SObjectType> allobj = AuthController.whiteList;
        Map<String, Schema.SObjectType> allObjects = new Map<String, Schema.SObjectType>();
        
        for(String objName : allobj.keySet()) {
            if(doChecked.contains(objName)) {
                allObjects.put(objName, allobj.get(objName));
            }
        }
        return allObjects;
    }
    
    
    
    private static Map<String, Schema.SObjectType> separateParentsChilds(Map<String, Schema.SObjectType> allobj) { //Separate parents and childs
        Map<String, Map<String, Schema.SObjectType>> separated = new Map<String, Map<String, Schema.SObjectType>>();
        Map<String, Schema.SObjectType> parents = new Map<String, Schema.SObjectType>();
        Map<String, Schema.SObjectType> childs = new Map<String, Schema.SObjectType>();
        
        List<Map<String, Object>> objList = new List<Map<String, Object>>();
        for(String objName : allobj.keySet()) {
            Schema.DescribeSObjectResult dor = allobj.get(objName).getDescribe();
            parents.put(objName, allobj.get(objName));
            if(objName.equalsIgnoreCase('Contact') || objName.equalsIgnoreCase('Opportunity')) {
                childs.put(objName, allobj.get(objName));
            }
            List<Schema.ChildRelationship> crList = dor.getChildRelationships();
            for(Schema.ChildRelationship cr : crList) {
                String childObjName = cr.getChildSObject().getDescribe().getName().toLowerCase();
                if(cr.getField().getDescribe().getRelationshipOrder() != null && allobj.containsKey(childObjName)) {
                    childs.put(childObjName, allobj.get(childObjName));
                }
            }
        }
        
        for(String objName : childs.keySet()) {
            parents.remove(objName);
        }

        return parents;
    }
}