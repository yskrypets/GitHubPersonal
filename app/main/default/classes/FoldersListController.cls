public with sharing class FoldersListController {
    private static String token;
    private static Boolean tokenRefreshed = false;
    private static final String mainFolderName = 'Salesforce Root';
    
    
    @AuraEnabled //check if user authorized and have access for login/logout
    public static Object checkAuthorizing() {
        return AuthController.checkAuthorizingWithoutSave();
    }
    
    
    
    @AuraEnabled //Check saved files action
    public static String checkFilesAction() {
        String action = Drive__c.getOrgDefaults().Files_Action__c;
        if(action == null || action == '') {
            return 'nothing';
        } 

        return action;
    }
    
    
    @AuraEnabled //Fill list of subfolders
    public static String fillSubfolders() {
        List<FoldersListControllerClassic.Folders> subfolders = new List<FoldersListControllerClassic.Folders>();
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Label__c.isAccessible() 
          && Schema.sObjectType.Subfolder__c.isAccessible() && Schema.sObjectType.Subfolder__c.Fields.Name.isAccessible()) {
            List<Drive_Object__c> drvObjList = [SELECT id, Name, Label__c, (SELECT id, Name FROM Subfolders__r) FROM Drive_Object__c];
            for(Drive_Object__c obj : drvObjList) {
                FoldersListControllerClassic.Folders fld = new FoldersListControllerClassic.Folders();
                fld.Name = obj.Name;
                fld.Label = obj.Label__c;
                if(!obj.Subfolders__r.isEmpty()) {
                    fld.Childs = new List<FoldersListControllerClassic.Folders>();
                    for(Subfolder__c sub : obj.Subfolders__r) {
                        FoldersListControllerClassic.Folders cld = new FoldersListControllerClassic.Folders();
                        cld.Name = sub.Name;
                        fld.Childs.add(cld);
                    }
                }
                subfolders.add(fld);
            }
            subfolders.sort();
        }
        return JSON.serialize(subfolders);
    }
    
    
    @AuraEnabled //Add subfolder
    public static String addSubfolderCtrl(String recordTempName, String subfolderName) {
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() &&
          Schema.sObjectType.Subfolder__c.isCreateable() && Schema.sObjectType.Subfolder__c.Fields.Name.isCreateable() && Schema.sObjectType.Subfolder__c.Fields.Drive_Object__c.isCreateable()) {
            List<Drive_Object__c> drvObjList = [SELECT id, Name FROM Drive_Object__c];
            List<Subfolder__c> newSubs = new List<Subfolder__c>();
            for(Drive_Object__c obj : drvObjList) {
                if(obj.Name.equalsIgnoreCase(recordTempName)) {
                    newSubs.add(new Subfolder__c(Drive_Object__c=obj.id, Name=subfolderName));
                }
            }
            if(!newSubs.isEmpty()) insert newSubs;
        }
        return fillSubfolders();
    }
    
    
    @AuraEnabled //Remove subfolder
    public static String removeSubfolderCtrl(String recordTempName, String subfolderName) {
        List<Subfolder__c> subsForRemove = new List<Subfolder__c>();
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() 
           && Schema.sObjectType.Subfolder__c.isAccessible() && Schema.sObjectType.Subfolder__c.Fields.Name.isAccessible()) {
            List<Drive_Object__c> drvObjList = [SELECT id, Name, (SELECT id, Name FROM Subfolders__r) FROM Drive_Object__c];
            for(Drive_Object__c obj : drvObjList) {
                if(obj.Name.equalsIgnoreCase(recordTempName) && !obj.Subfolders__r.isEmpty()) {
                    for(Subfolder__c sub : obj.Subfolders__r) {
                        if(sub.Name.equalsIgnoreCase(subfolderName)) subsForRemove.add(new Subfolder__c(id=sub.id));
                    }
                }
            }
        }
        if(!subsForRemove.isEmpty() && Schema.sObjectType.Subfolder__c.isDeletable()) delete subsForRemove;
        return fillSubfolders();
    }
    

    @AuraEnabled     //Action with files
    public static String actionWithFiles(String value) {
        token = AuthController.CheckTokenAvailability();
        if(token == null) {
            token = AuthController.getAccessToken();
        }
        if(token != null) {
            Database.executeBatch(new FilesActionsBatch(value, token), 1);
            Database.executeBatch(new FilesActionsClassicBatch(value, token), 1);
            
            Drive__c drive = Drive__c.getOrgDefaults();
            drive.Files_Action__c = value;
            if(Schema.sObjectType.Drive__c.isUpdateable() &&
               Schema.sObjectType.Drive__c.isCreateable() &&
               Schema.sObjectType.Drive__c.Fields.Files_Action__c.isUpdateable() &&
               Schema.sObjectType.Drive__c.Fields.Files_Action__c.isCreateable())
                upsert drive;
        }
        
        return 'SUCCESS';
    }
    
    
    @AuraEnabled //Save Action
    public static String saveActionWithFiles(String value) {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.Files_Action__c = value;
        if(Schema.sObjectType.Drive__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.isCreateable() &&
           Schema.sObjectType.Drive__c.Fields.Files_Action__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.Files_Action__c.isCreateable())
            upsert drive;
        
        return 'SUCCESS';
    }
    
    
    @AuraEnabled     //Return list of Salesforce objects
    public static List<Object> getFolders() {
        List<Map<String, Object>> objList = getObjectsList();
        List<FoldersListControllerClassic.Folders> defFolders = fillFoldersList(objList, null);
        List<Object> folders = (List<Object>) JSON.deserializeUntyped(JSON.serialize(defFolders));
        return folders;
    }
    
 
    @AuraEnabled    //Create/Delete objects folders
    public static List<Object> updDriveFolders(String folders) {
        List<Object> fldList = (List<Object>) JSON.deserializeUntyped(folders);
        foldersUpdate(fldList);
        return fldList;
    }
    
//---------------    
    
    private static List<FoldersListControllerClassic.Folders> fillFoldersList(List<Object> objList, String parentName) {
        List<FoldersListControllerClassic.Folders> fldList = new List<FoldersListControllerClassic.Folders>();
        for(Object obj : objList) {
            Map<String, Object> objMap = (Map<String, Object>) obj;
            //if(!(Boolean) objMap.get('Checked')) selectAll = false;
            FoldersListControllerClassic.Folders fld = new FoldersListControllerClassic.Folders();
            fld.Checked = (parentName != null && parentName.equalsIgnoreCase((String) objMap.get('Parent'))) || parentName == null ? (Boolean) objMap.get('Checked') : false;
            fld.hasChilds = (Boolean) objMap.get('hasChilds');
            fld.Opened = (Boolean) objMap.get('Opened');
            fld.Name = (String) objMap.get('Name');
            fld.Label = (String) objMap.get('Label');
            fld.Parent = parentName;
            
            if((Boolean) objMap.get('hasChilds')) {
                fld.Childs = fillFoldersList((List<Map<String, Object>>) objMap.get('Childs'), (String) objMap.get('Name'));
            }
            fldList.add(fld);
        }
        return fldList;
    }
    
    
    
    private static void foldersUpdate(List<Object> fldList) {
        Map<String, Drive_Object__c> doMap = new Map<String, Drive_Object__c>();
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && 
           Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() &&
           Schema.sObjectType.Drive_Object__c.Fields.Label__c.isAccessible() && 
           Schema.sObjectType.Drive_Object__c.Fields.isCreated__c.isAccessible() &&
           Schema.sObjectType.Drive_Object__c.Fields.Parent_Object__c.isAccessible()) {
               for(Drive_Object__c dob : [SELECT id, Name, Label__c, isCreated__c, Parent_Object__c FROM Drive_Object__c LIMIT 50000]) {
                   doMap.put(dob.Name, dob);
               }
           }

        foldersUpdateHelper(fldList, doMap);
        
        if(Schema.sObjectType.Drive_Object__c.isCreateable() && 
           Schema.sObjectType.Drive_Object__c.isUpdateable() &&
           Schema.sObjectType.Drive_Object__c.Fields.Name.isCreateable() &&
           Schema.sObjectType.Drive_Object__c.Fields.Name.isUpdateable() &&
           Schema.sObjectType.Drive_Object__c.Fields.Label__c.isCreateable() &&
           Schema.sObjectType.Drive_Object__c.Fields.Label__c.isUpdateable() &&
           Schema.sObjectType.Drive_Object__c.Fields.isCreated__c.isCreateable() &&
           Schema.sObjectType.Drive_Object__c.Fields.isCreated__c.isUpdateable() && 
           Schema.sObjectType.Drive_Object__c.Fields.Parent_Object__c.isCreateable() &&
           Schema.sObjectType.Drive_Object__c.Fields.Parent_Object__c.isUpdateable()) {
           		upsert doMap.values();
           }
    }
    
    
    private static void foldersUpdateHelper(List<Object> fldList, Map<String, Drive_Object__c> doMap) {
        for(Object folder : fldList) {
            Map<String, Object> folderMap = (Map<String, Object>) folder;
            if(doMap.containsKey((String) folderMap.get('Name'))) {
                if((Boolean) folderMap.get('Checked')) {
                    doMap.get((String) folderMap.get('Name')).isCreated__c = (Boolean) folderMap.get('Checked');
                    doMap.get((String) folderMap.get('Name')).Parent_Object__c = (String) folderMap.get('Parent');
                } else if(doMap.get((String) folderMap.get('Name')).Parent_Object__c == (String) folderMap.get('Parent')) {
                    doMap.get((String) folderMap.get('Name')).isCreated__c = (Boolean) folderMap.get('Checked');
                }
            } else {
                doMap.put((String) folderMap.get('Name'), new Drive_Object__c(Name=(String) folderMap.get('Name'), Label__c=(String) folderMap.get('Label'), isCreated__c=(Boolean) folderMap.get('Checked'), Parent_Object__c=(String) folderMap.get('Parent')));
            }
            //system.debug(folderMap.get('Name') + ' --- ' + folderMap.get('Checked') + ' --- ' + doMap.get((String) folderMap.get('Name')).isCreated__c);
            if((Boolean) folderMap.get('hasChilds')) {
                foldersUpdateHelper((List<Object>) folderMap.get('Childs'), doMap);
            }
        }
    }
    
    
    public static void DeleteFolder(String folderId, String token) {    //Delete object folder
        HttpRequest req = new HttpRequest();
        req.setMethod('DELETE');
        Drive__c drive = Drive__c.getOrgDefaults();
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
        		req.setEndpoint('https://www.googleapis.com/drive/v2/files/' + folderId);
            }
            when 'onedrive' {
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + folderId);
                req.setHeader('Accept', 'application/*');
            }
        }
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        h.send(req);
    }
    
    
    public static List<Map<String, Object>> getObjectsList() {    //Get list of salesforce objects
        Map<String, String> doLabels = new Map<String, String>();
        
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && 
           Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() &&
           Schema.sObjectType.Drive_Object__c.Fields.Label__c.isAccessible() && 
           Schema.sObjectType.Drive_Object__c.Fields.isCreated__c.isAccessible() && 
           Schema.sObjectType.Drive_Object__c.Fields.Parent_Object__c.isAccessible()) {
            for(Drive_Object__c dob : [SELECT id, Name, Label__c, isCreated__c, Parent_Object__c FROM Drive_Object__c WHERE isCreated__c = true]) {
                doLabels.put(dob.Label__c, dob.Parent_Object__c);
            }
        }
        
        //String mainFolderId = getFolderId(mainFolderName, null);
        
        Map<String, Schema.SObjectType> forSeparate = AuthController.whiteList;
        List<Map<String, Object>> objList = new List<Map<String, Object>>();

        Map<String, Map<String, Schema.SObjectType>> separated = separateParentsChilds(forSeparate);
        for(String objName : separated.get('parents').keySet()) {
            Schema.DescribeSObjectResult dor = separated.get('parents').get(objName).getDescribe();
            Map<String, Object> obj = new Map<String, Object>();
            obj.put('Label', dor.getLabel());
            obj.put('Name', dor.getName());
            obj.put('hasChilds', false);
            obj.put('Childs', new List<Map<String, Object>>());
            obj.put('Opened', true);
            obj.put('Checked', doLabels.containsKey(dor.getLabel()) || doLabels.isEmpty() ? true : false);
            obj.put('Parent', doLabels.containsKey(dor.getLabel()) ? doLabels.get(dor.getLabel()) : '');

            formatChild(obj, dor, separated, forSeparate, doLabels);
            
            if(dor.getName().equalsIgnoreCase('Account')) {
                obj.put('hasChilds', true);
                List<Object> childsList = (List<Object>) obj.get('Childs');
                Schema.DescribeSObjectResult chlDor = separated.get('childs').get('contact').getDescribe();
                Map<String, Object> chlObj = new Map<String, Object>();
                chlObj.put('Label', chlDor.getLabel());
                chlObj.put('Name', chlDor.getName());
                chlObj.put('hasChilds', false);
                chlObj.put('Childs', new List<Map<String, Object>>());
                chlObj.put('Opened', true);
                chlObj.put('Checked', doLabels.containsKey(chlDor.getLabel()) || doLabels.isEmpty() ? true : false);
                chlObj.put('Parent', doLabels.containsKey(chlDor.getLabel()) ? doLabels.get(chlDor.getLabel()) : '');
                formatChild(chlObj, separated.get('childs').get('contact').getDescribe(), separated, forSeparate, doLabels);
                childsList.add(chlObj);

                chlDor = separated.get('childs').get('opportunity').getDescribe();
                chlObj = new Map<String, Object>();
                chlObj.put('Label', chlDor.getLabel());
                chlObj.put('Name', chlDor.getName());
                chlObj.put('hasChilds', false);
                chlObj.put('Childs', new List<Map<String, Object>>());
                chlObj.put('Opened', true);
                chlObj.put('Checked', doLabels.containsKey(chlDor.getLabel()) || doLabels.isEmpty() ? true : false);
                chlObj.put('Parent', doLabels.containsKey(chlDor.getLabel()) ? doLabels.get(chlDor.getLabel()) : '');
                formatChild(chlObj, separated.get('childs').get('opportunity').getDescribe(), separated, forSeparate, doLabels);
                childsList.add(chlObj);

                obj.put('Childs', childsList);
            }
            
            objList.add(obj);
        }
        
        if(tokenRefreshed) AuthController.SaveRefreshedToken(token);
        
        return objList;
    }
    
    
    private static void formatChild(Map<String, Object> obj, Schema.DescribeSObjectResult dor, Map<String, Map<String, Schema.SObjectType>> separated, Map<String, Schema.SObjectType> allobj, Map<String, String> doLabels) {    //Child formating
        List<Schema.ChildRelationship> crList = dor.getChildRelationships();
        for(Schema.ChildRelationship cr : crList) {
            String childObjName = cr.getChildSObject().getDescribe().getName().toLowerCase();
            if(cr.getField().getDescribe().getRelationshipOrder() != null && allobj.containsKey(childObjName)) {
                Map<String, Object> childFoldersMap = new Map<String, Object>();
                
                obj.put('hasChilds', true);
                
                Schema.DescribeSObjectResult childDor = separated.get('childs').get(childObjName).getDescribe();
                
                List<Map<String, Object>> childList = (List<Map<String, Object>>) obj.get('Childs');
                Map<String, Object> childObj = new Map<String, Object>();
                childObj.put('Label', childDor.getLabel());
                childObj.put('Name', childDor.getName());
                childObj.put('Childs', new List<Map<String, Object>>());
                childObj.put('Opened', true);
                childObj.put('Checked', doLabels.containsKey(childDor.getLabel()) || doLabels.isEmpty() ? true : false);
                childObj.put('Parent', doLabels.containsKey(childDor.getLabel()) ? doLabels.get(childDor.getLabel()) : '');
                childObj.put('hasChilds', false);
                formatChild(childObj, separated.get('childs').get(childObjName).getDescribe(), separated, allobj, doLabels);
                
                childList.add(childObj);
                obj.put('Childs', childList);
            }
        }
    }
    
    
    private static Map<String, Map<String, Schema.SObjectType>> separateParentsChilds(Map<String, Schema.SObjectType> allobj) {    //Separate parents and childs
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
        
        separated.put('parents', parents);
        separated.put('childs', childs);
        return separated;
    }
    
    
    public static void moveFolder(String folderId, String targeParentId, String oldParentId, String token) {    //Move folder to another parent folder
        HttpRequest req = new HttpRequest();
        String body;
        Drive__c drive = Drive__c.getOrgDefaults();
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                req.setEndpoint('https://content.googleapis.com/drive/v3/files/' + folderId + '?addParents=' + targeParentId + '&removeParents=' + oldParentId);
                body = JSON.serialize(new Map<String, Object>{'mimeType'=>'application/vnd.google-apps.folder'});
            }
            when 'onedrive' {
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + folderId);
                req.setHeader('Accept', 'application/*');
                body = JSON.serialize(new Map<String, Object>{'parentReference'=>new Map<String, Object>{'id'=>targeParentId}});
            }
        }
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('X-HTTP-Method', 'PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Content-Length', String.valueOf(body.length()));
        req.setBody(body);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        system.debug(res.getBody());
    }
    
    
    public static String getFolderId(String folderName, String parentFolderId) {     //Get folder id from Google Drive by name and parent folder id
        String parentId = '';
        if(parentFolderId != null) parentId = '%20and%20%27' + parentFolderId + '%27%20in%20parents';
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint('https://content.googleapis.com/drive/v3/files?q=mimeType%3D%27application%2Fvnd.google-apps.folder%27%20and%20name=%27' + folderName.replaceAll(' ', '%20') + '%27%20and%20trashed%3Dfalse' + parentId);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*1000);

        Http h = new Http();         HttpResponse res = h.send(req);
        String resp = res.getBody();

        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        if(respMap.containsKey('files')) {
            List<Object> files = (List<Object>) respMap.get('files');
            if(!files.isEmpty()) {
                Map<String, Object> file = (Map<String, Object>) files.get(0);
                return (String) file.get('id');
            } else if(folderName.equalsIgnoreCase('Archived')) {
                return FilesController.CreateSubFolder(folderName, parentFolderId, token, false);
            }
        }
        return null;
    }
}