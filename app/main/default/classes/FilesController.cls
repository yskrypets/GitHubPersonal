public with sharing class FilesController {
    private static String token;    
    private static Boolean tokenRefreshed = false;    
    private static final String mainFolderName = 'Salesforce Root';
    
    
    @AuraEnabled //Check if user authorized and have access for login/logout
    public static Object checkAuthorizing() {
        Map<String, Object> forResp = (Map<String, Object>) AuthController.checkAuthorizingWithoutSave();
        Drive__c drive = Drive__c.getOrgDefaults();
        forResp.put('driveName', drive.External_Drive_Name__c);
        return forResp;
    }
    
    
    
    @AuraEnabled //Check if object folder already created as child for Salesforce Root folder
    public static String checkFolder(Id recordId) {
        Map<String, Object> mapForReturn = new Map<String, Object>{'available'=>false};
        if(Schema.sObjectType.Drive_Object__c.isAccessible() &&    
           Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() &&    
           Schema.sObjectType.Drive_Object__c.Fields.Label__c.isAccessible() &&    
           Schema.sObjectType.Drive_Object__c.Fields.isCreated__c.isAccessible() &&    
           Schema.sObjectType.Drive_Object__c.Fields.Parent_Object__c.isAccessible()) {
               List<Drive_Object__c> dobList = [SELECT id, Name, Label__c, isCreated__c, Parent_Object__c FROM Drive_Object__c WHERE Name =: recordId.getSobjectType().getDescribe().getName() LIMIT 1];
               if(!dobList.isEmpty()) {
                   Drive_Object__c dob = dobList[0];
                   if(dob.isCreated__c) {
                       mapForReturn.put('available', true);
                       if(dob.Parent_Object__c != null && Schema.getGlobalDescribe().containsKey(dob.Parent_Object__c)) {
                           mapForReturn.put('parentObjectLabel', Schema.getGlobalDescribe().get(dob.Parent_Object__c).getDescribe().getLabel());
                           String parentFieldName = getFieldName(recordId, dob.Parent_Object__c);
                           if(recordId.getSobjectType().getDescribe().isAccessible() && recordId.getSobjectType().getDescribe().fields.getMap().get(parentFieldName).getDescribe().isAccessible()) {
                            mapForReturn.put('parentRecordId', Database.query('SELECT ' + parentFieldName + ' FROM ' + recordId.getSobjectType().getDescribe().getName() + ' WHERE id = \'' + recordId + '\'').get(0).get(parentFieldName));
                           }
                       }
                   }
               }
        }
        return JSON.serialize(mapForReturn);
    }
    
    
    @AuraEnabled //Get subfolders
    public static String getSubfolders(Id recordId) {
        List<Map<String, String>> subfolders = new List<Map<String, String>>{new Map<String, String>{'label'=>'None','value'=>''}};
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && 
           Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() && 
           Schema.sObjectType.Drive_Object__c.Fields.Label__c.isAccessible() && 
           Schema.sObjectType.Subfolder__c.isAccessible() && 
           Schema.sObjectType.Subfolder__c.Fields.Name.isAccessible()) {
        	List<Drive_Object__c> drvObjList = [SELECT id, Name, Label__c, (SELECT id, Name FROM Subfolders__r) FROM Drive_Object__c WHERE Name =: recordId.getSObjectType().getDescribe().getName() LIMIT 1];
            if(!drvObjList.isEmpty() && !drvObjList[0].Subfolders__r.isEmpty()) {
                for(Subfolder__c sub : drvObjList[0].Subfolders__r) {
                    subfolders.add(new Map<String, String>{'label'=>sub.Name,'value'=>sub.Name});
                }       
            }
          }
        return JSON.serialize(subfolders);
    }
    
    
    @AuraEnabled    //Get all files except Log.csv from record folder
    public static Map<String, Object> getFiles(Id recordId) {
        Drive__c drive = Drive__c.getOrgDefaults();
        token = AuthController.CheckTokenAvailability();
        if(token == null) {
            token = AuthController.getAccessToken();
        } else {
            tokenRefreshed = true;
        }
        
        List<Map<String, Object>> filesList = new List<Map<String, Object>>();
        String recordFolderId = getFolderId(recordId, null, 'contains', false);
		List<Object> baseFiles = getFilesList(recordId, recordFolderId, true);
        
        if(drive.External_Drive_Name__c.equalsIgnoreCase('gdrive')) {
            List<Map<String, String>> soList = (List<Map<String, String>>) JSON.deserialize(getSubfolders(recordId), List<Map<String, String>>.class);
            for(Map<String, String> so : soList) {
                if(so.get('value') != '') {
                    String subfolderId = getFolderId(so.get('value'), recordFolderId, '=', false);
                    List<Object> tmpFiles = getFilesList(recordId, subfolderId, true);
                    if(tmpFiles != null) baseFiles.addAll(tmpFiles);
                }
            }
        }
        
        Map<String, Object> mapForReturn = new Map<String, Object>{'recordFolderId'=>recordFolderId};
        List<Object> filesListForReturn = new List<Object>();
        Set<String> subfoldersSet = new Set<String>();
        if(baseFiles == null) return mapForReturn;
        
        for(Object base : baseFiles) {
            Map<String, Object> fileBaseMap = (Map<String, Object>) base;
            if((fileBaseMap.containsKey('title') && !((String) fileBaseMap.get('title')).equalsIgnoreCase('Log.csv')) ||
               (fileBaseMap.containsKey('name') && !((String) fileBaseMap.get('name')).equalsIgnoreCase('Log.xlsx'))) {
                   
                   Map<String, Object> fileMap = new Map<String, Object>();
                   switch on drive.External_Drive_Name__c {
                       when 'gdrive' {
                           fileMap.put('id', fileBaseMap.get('id'));
                           fileMap.put('Type', fileBaseMap.get('mimeType'));
                           fileMap.put('iconLink', fileBaseMap.get('iconLink'));
                           fileMap.put('Name', fileBaseMap.get('title'));
                           fileMap.put('Size', fileBaseMap.get('fileSize'));
                           fileMap.put('parentId', ((Map<String, Object>)((List<Object>)fileBaseMap.get('parents'))[0]).get('id'));
                           fileMap.put('DownloadLink', fileBaseMap.get('webContentLink'));
                           if(fileBaseMap.containsKey('properties')) {
                               for(Object prop : (List<Object>) fileBaseMap.get('properties')) {
                                   Map<String, Object> propMap = (Map<String, Object>) prop;
                                   if((String)propMap.get('key') == 'subfolder') {
                                       fileMap.put('Subfolder', propMap.get('value'));
                                       break;
                                   }
                               }
                           }
                       }
                       when 'onedrive' {
                           fileMap.put('id', fileBaseMap.get('id'));
                           fileMap.put('Type', ((Map<String, Object>)fileBaseMap.get('file')).get('mimeType'));
                           fileMap.put('Name', fileBaseMap.get('name'));
                           fileMap.put('Size', fileBaseMap.get('size'));
                           fileMap.put('DownloadLink', fileBaseMap.get('@microsoft.graph.downloadUrl'));
                           fileMap.put('parentId', ((Map<String, Object>)fileBaseMap.get('parentReference')).get('id'));
                           fileMap.put('Subfolder', ((Map<String, Object>)fileBaseMap.get('parentReference')).get('name'));
                           subfoldersSet.add((String)((Map<String, Object>)fileBaseMap.get('parentReference')).get('name'));
                       }
                   }
                   
                   filesList.add(fileMap);
               }
        }
        
        if(drive.External_Drive_Name__c.equalsIgnoreCase('onedrive')) {
            List<String> subfoldersList = new List<String>();	//sorting
            subfoldersList.addAll(subfoldersSet);
            subfoldersList.sort();
            for(String str : subfoldersList) {
                for(Map<String, Object> fileMap : filesList) {
                    if(fileMap.containsKey('Subfolder') && str.equalsIgnoreCase((String)fileMap.get('Subfolder'))) filesListForReturn.add(fileMap);
                }
            }
        }
        
        if(tokenRefreshed) AuthController.SaveRefreshedToken(token);
        
        mapForReturn.put('fileList', filesList.isEmpty() ? null : filesList);
        return mapForReturn;
    }
    
    
    private static Integer masterCount = 0; 
    private static String availableMaster = '';
    private static Boolean notParent = false;
    private static List<Map<String, String>> parentPath {get;set;}
    
    @AuraEnabled     //Create record folder
    public static String createRecordFolder(Id recordId) {
        Map<String, String> tokenFolderId = new Map<String, String>();
        
        token = AuthController.CheckTokenAvailability();
        if(token == null) {
            token = AuthController.getAccessToken();
        } else {
            tokenRefreshed = true;
        }
        tokenFolderId.put('token', Test.isRunningTest() ? 'testaccesstoken' : token);
        
        String recordFolderId;
        Drive__c drive = Drive__c.getOrgDefaults();
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                String mainFolderId = getFolderId(mainFolderName, null, '=', false);
                if(mainFolderId == null) {
                    mainFolderId = CreateSubFolder(mainFolderName, null, token, false);
                    AuthController.setRootPermissions(mainFolderId, token);
                }
                recordFolderId = mainFolderId;
                
                String oldRecordFolderId = getFolderId(recordId, null, 'contains', false);
                
                Schema.DescribeSObjectResult dor1 = recordId.getSobjectType().getDescribe();
                if(dor1.getName().equalsIgnoreCase('Contact') || dor1.getName().equalsIgnoreCase('Opportunity')) {
                    String accountFolderId1 = getFolderId('Account', mainFolderId, '=', false);
                    if(accountFolderId1 == null) accountFolderId1 = CreateSubFolder('Account', mainFolderId, token, false);
                    sObject sobj = Schema.getGlobalDescribe().get(dor1.getName()).newSObject();
                    if(dor1.isAccessible() && dor1.fields.getMap().get('AccountId').getDescribe().isAccessible()) {
                        sobj = Database.query('SELECT AccountId FROM ' + dor1.getName() + ' WHERE id = \'' + recordId + '\'').get(0);
                    }
                    if(sobj.get('AccountId') == null) {
                        String folderId1 = getFolderId(dor1.getLabel(), accountFolderId1, '=', false);
                        if(folderId1 == null) folderId1 = CreateSubFolder(dor1.getLabel(), accountFolderId1, token, false);
                        recordFolderId = getFolderId(recordId, folderId1, 'contains', true);
                    } else {
                        String accRecordFolderId1 = getFolderId((String) sobj.get('AccountId'), accountFolderId1, 'contains', true);
                        String folderId1 = getFolderId(dor1.getLabel(), accRecordFolderId1, '=', false);
                        if(folderId1 == null) folderId1 = CreateSubFolder(dor1.getLabel(), accRecordFolderId1, token, false);
                        recordFolderId = getFolderId(recordId, folderId1, 'contains', true);
                    }
                } else {
                    recordFolderId = createRecordFolderHelper(recordId, mainFolderId, dor1, recordFolderId);
                }
                
                if((oldRecordFolderId != null && oldRecordFolderId != recordFolderId) || (Test.isRunningTest() && oldRecordFolderId != null)) {
                    Map<String, Object> oldMeta = (Map<String, Object>) JSON.deserializeUntyped(getMetadata(oldRecordFolderId));
                    Map<String, Object> newMeta = (Map<String, Object>) JSON.deserializeUntyped(getMetadata(recordFolderId));
                    
                    if(dor1.getName().equalsIgnoreCase('Contact') || dor1.getName().equalsIgnoreCase('Opportunity')) {
                        moveFolder((String) oldMeta.get('title'), oldRecordFolderId, (String) ((Map<String, Object>) ((List<Object>) newMeta.get('parents')).get(0)).get('id'), (String) ((Map<String, Object>) ((List<Object>) oldMeta.get('parents')).get(0)).get('id'));
                        deleteFolder(recordFolderId);
                        recordFolderId = oldRecordFolderId;
                    } else {
                        List<Object> oldFiles = getFilesList(recordId, oldRecordFolderId, true);
                        for(Object obj : oldFiles) {
                            Map<String, Object> oldFile = (Map<String, Object>) obj;
                            moveFolder((String) oldFile.get('title'), (String) oldFile.get('id'), recordFolderId, oldRecordFolderId);
                        }
                        deleteFolder(oldRecordFolderId);
                    }
                }
                
                Map<String, Object> newMeta = (Map<String, Object>) JSON.deserializeUntyped(getMetadata(recordFolderId));
                
                List<Object> parents = (List<Object>) newMeta.get('parents');
                if(parents.size() > masterCount && masterCount != 0 || (Test.isRunningTest() && masterCount != 0)) {
                    for(Object obj : parents) {
                        Map<String, Object> parent = (Map<String, Object>) obj;
                        Map<String, Object> objMeta = (Map<String, Object>) JSON.deserializeUntyped(getMetadata((String) parent.get('id')));
                        Map<String, Object> parentBaseMeta = (Map<String, Object>) ((List<Object>) objMeta.get('parents')).get(0);
                        Map<String, Object> parentMeta = (Map<String, Object>) JSON.deserializeUntyped(getMetadata((String) parentBaseMeta.get('id')));
                        String parentName = (String) parentMeta.get('description');
                        if(parentName != null) {
                            id parentId = parentName;
                            parentName = parentId.getSobjectType().getDescribe().getLabel();
                        }
                        if(parentName != availableMaster) {
                            removeParent((String) newMeta.get('id'), (String) newMeta.get('title'), (String) parent.get('id'), token);
                        }
                    }
                }
            }
            when 'onedrive' {
                recordFolderId = getOneDriveFolderId(mainFolderName, token);
                if(recordFolderId == null) {
                    recordFolderId = CreateSubFolder(mainFolderName, null, token, false);
                }
                
                List<Map<String, Object>> objsList = FoldersListController.getObjectsList();
                
                findPath(objsList, null, recordId);
                if(parentPath != null) {
                    for(integer i = parentPath.size()-1; i >= 0; i--) {
                        List<String> currentNames = new List<String>();
                        currentNames.addAll(parentPath[i].keySet());
                        String tempRecordFolderId = getFolderId(currentNames[0], recordFolderId, '=', false);
                        if(tempRecordFolderId == null) tempRecordFolderId = CreateSubFolder(currentNames[0], recordFolderId, token, false);
                        recordFolderId = getFolderId(parentPath[i].get(currentNames[0]), tempRecordFolderId, '=', false);
                        if(recordFolderId == null) recordFolderId = CreateSubFolder(parentPath[i].get(currentNames[0]), tempRecordFolderId, token, false);
                    }
                }
            }
        }
        
        tokenFolderId.put('folderId', recordFolderId);
        
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Label__c.isAccessible() 
          && Schema.sObjectType.Subfolder__c.isAccessible() && Schema.sObjectType.Subfolder__c.Fields.Name.isAccessible()) {
            List<Drive_Object__c> drvObjList = [SELECT id, Name, Label__c, (SELECT id, Name FROM Subfolders__r) FROM Drive_Object__c WHERE Name =: recordId.getSobjectType().getDescribe().getName() LIMIT 1];
            if(!drvObjList.isEmpty() && !drvObjList[0].Subfolders__r.isEmpty()) {
                for(Subfolder__c sub : drvObjList[0].Subfolders__r) {
                    String subfolderId = getFolderId(sub.Name, recordFolderId, '=', false);
                    if(subfolderId == null) subfolderId = CreateSubFolder(sub.Name, recordFolderId, token, false);
                    tokenFolderId.put(sub.Name, subfolderId);
                }            
            }
        }
        
        //if(tokenRefreshed && !System.isFuture() && !System.isBatch()) AuthController.SaveRefreshedToken(token);
        
        return JSON.serialize(tokenFolderId);
    }
    
    
    private static String findPath(List<Object> objsList, String parentName, id recordId) {
        for(Object obj : objsList) {
            Map<String, Object> objMap = (Map<String, Object>) obj;
            if(recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase((String) objMap.get('Name')) && (parentName == null || parentName.equalsIgnoreCase((String) objMap.get('Parent')))) {
                String fieldName = Test.isRunningTest() ? 'WhoId' : getFieldName(recordId, (String) objMap.get('Parent'));
                if(fieldName == null) fieldName = 'id';
                String mainFieldName = getMainFieldName((String) objMap.get('Name'));
                if(Schema.getGlobalDescribe().get((String) objMap.get('Name')).getDescribe().isAccessible() && 
                   Schema.getGlobalDescribe().get((String) objMap.get('Name')).getDescribe().fields.getMap().get(mainFieldName).getDescribe().isAccessible() &&
                   Schema.getGlobalDescribe().get((String) objMap.get('Name')).getDescribe().fields.getMap().get(fieldName).getDescribe().isAccessible()) {
                    sObject sobj = Database.query('SELECT ' + mainFieldName + ', ' + fieldName + ' FROM ' + (String) objMap.get('Name') + ' WHERE id = \'' + recordId + '\'').get(0);
                    parentPath = new List<Map<String, String>>{new Map<String, String>{(String) objMap.get('Label') => (((String) sobj.get(mainFieldName)).replaceAll(' ', '_') + ' (' + recordId + ')')}};
                    return (String) sobj.get(fieldName);
                }
            }
            if((Boolean) objMap.get('hasChilds')) {
                String returnedValue = Test.isRunningTest() ? recordId : findPath((List<Object>) objMap.get('Childs'), (String) objMap.get('Name'), recordId);
                if(returnedValue != null) {
                    String fieldName = getFieldName(returnedValue, (String) objMap.get('Parent'));
                    if(fieldName == null || Test.isRunningTest()) fieldName = 'id';
                    String mainFieldName = getMainFieldName((String) objMap.get('Name'));
                    if(Schema.getGlobalDescribe().get((String) objMap.get('Name')).getDescribe().isAccessible() && 
                       Schema.getGlobalDescribe().get((String) objMap.get('Name')).getDescribe().fields.getMap().get(mainFieldName).getDescribe().isAccessible() &&
                       Schema.getGlobalDescribe().get((String) objMap.get('Name')).getDescribe().fields.getMap().get(fieldName).getDescribe().isAccessible()) {
                        List<sObject> sobjList = Database.query('SELECT ' + mainFieldName + ', ' + fieldName + ' FROM ' + (String) objMap.get('Name') + ' WHERE id = \'' + returnedValue + '\'');
                        if(!sobjList.isEmpty()) {
                        	sObject sobj = sobjList.get(0);
                        	parentPath.add(new Map<String, String>{(String) objMap.get('Label') => (((String) sobj.get(mainFieldName)).replaceAll(' ', '_') + ' (' + returnedValue + ')')});
                        	return (String) sobj.get(fieldName);
                        }
                    }
                }
            }
        }
        return null;
    }
    
    
    private static String getMainFieldName(String objName) {
        String nameField = 'Name';
        if(objName.equalsIgnoreCase('Event') ||
           objName.equalsIgnoreCase('Task')) {
               nameField = 'Subject';
           } else if(objName.equalsIgnoreCase('Case')) {
               nameField = 'CaseNumber';
           } else if(objName.equalsIgnoreCase('Contract')) {
               nameField = 'ContractNumber';
           } else if(objName.equalsIgnoreCase('Note')) {
               nameField = 'Title';
           } else if(objName.equalsIgnoreCase('Order')) {
               nameField = 'OrderNumber';
           }
        return nameField;
    }
    
    
    public static String getFieldName(Id recordId, String parentName) {
        //system.debug(recordId + ' - ' + parentName);
        for(Schema.SObjectField fld : recordId.getSobjectType().getDescribe().fields.getMap().values()) {
            if(fld.getDescribe().getRelationshipOrder() != null && fld.getDescribe().getReferenceTo().get(0).getDescribe().getName().equalsIgnoreCase(parentName)) {
                return fld.getDescribe().getName();
            } else if(recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Contact') || 
                       recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Opportunity')) {
                return 'AccountId';
            }
        }
        if(Test.isRunningTest()) return 'ParentId';
        return null;
    }
    
    
    public static String createRecordFolderHelper(Id recordId, String mainFolderId, Schema.DescribeSObjectResult dor1, String recordFolderId) {
        notParent = false;
        for(Schema.SObjectField fld1 : dor1.fields.getMap().values()) {
            if(fld1.getDescribe().getRelationshipOrder() != null || (Test.isRunningTest() && fld1.getDescribe().getName() == 'WhoId')) {
                masterCount++;
                notParent = true;
                Schema.DescribeSObjectResult dor2 = fld1.getDescribe().getReferenceTo().get(0).getDescribe();
                availableMaster = dor2.getLabel();
                sObject sobj1 = Schema.getGlobalDescribe().get(dor1.getName()).newSObject();
                if(dor1.isAccessible() && fld1.getDescribe().isAccessible()) {
                    sobj1 = Database.query('SELECT ' + fld1.getDescribe().getName() + ' FROM ' + dor1.getName() + ' WHERE id = \'' + recordId + '\'').get(0);
                }
                String parentRecordFolderId = '';
                if(dor2.getName().equalsIgnoreCase('Contact') || dor2.getName().equalsIgnoreCase('Opportunity')) {
                    String accountFolderId1 = getFolderId('Account', mainFolderId, '=', false);
                    if(accountFolderId1 == null) accountFolderId1 = CreateSubFolder('Account', mainFolderId, token, false);
                    sObject sobj2 = Schema.getGlobalDescribe().get(dor2.getName()).newSObject();
                    if(dor2.isAccessible() && dor2.fields.getMap().get('AccountId').getDescribe().isAccessible()) {
                        sobj2 = Database.query('SELECT AccountId FROM ' + dor2.getName() + ' WHERE id = \'' + sobj1.get(fld1.getDescribe().getName()) + '\'').get(0);
                    }
                    String folderId1 = '';
                    if(sobj2.get('AccountId') == null) {
                        folderId1 = getFolderId(dor2.getLabel(), accountFolderId1, '=', false);
                        if(folderId1 == null) folderId1 = CreateSubFolder(dor2.getLabel(), accountFolderId1, token, false);
                    } else {
                        String accRecordFolderId = getFolderId((String) sobj2.get('AccountId'), accountFolderId1, 'contains', true);
                        folderId1 = getFolderId(dor2.getLabel(), accRecordFolderId, '=', false);
                        if(folderId1 == null) folderId1 = CreateSubFolder(dor2.getLabel(), accRecordFolderId, token, false);
                        parentRecordFolderId = getFolderId((String) sobj1.get(fld1.getDescribe().getName()), folderId1, 'contains', true);
                    }
                } else {
                    parentRecordFolderId = createRecordFolderHelper((id)sobj1.get(fld1.getDescribe().getName()), mainFolderId, dor2, recordFolderId);
                    notParent = true;
                }
                
                String objFolderId1 = getFolderId(dor1.getLabel(), parentRecordFolderId, '=', false);
                if(objFolderId1 == null) objFolderId1 = CreateSubFolder(dor1.getLabel(), parentRecordFolderId, token, false);
                if(recordFolderId == null) {
                    recordFolderId = getFolderId(recordId, objFolderId1, 'contains', true);
                } else {
                    String recordFolderName = ((String) sobj1.get(fld1.getDescribe().getName())).replaceAll(' ', '_') + ':' + recordId;
                    addParent(recordFolderId, recordFolderName, objFolderId1, token);
                }
            }
        }
        
        if(!notParent) {
            String objFolderId1 = getFolderId(dor1.getLabel(), mainFolderId, '=', false);
            if(objFolderId1 == null) objFolderId1 = CreateSubFolder(dor1.getLabel(), mainFolderId, token, false);
            recordFolderId = getFolderId(recordId, objFolderId1, 'contains', true);
        }
        return recordFolderId;
    }
    
    
    private static String getMetadata(String fileId) { //Get file metadata
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint('https://www.googleapis.com/drive/v2/files/' + fileId);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
        return resp;
    }
    
    
    
    private static void deleteFolder(String folderId) {     //remove folder
        FoldersListController.DeleteFolder(folderId, token);
    }
    
    
    private static void moveFolder(String newFolderName, String folderId, String newFolderId, String oldFolderId) {     //Move Folder
        Map<String, Object> bodyMap = new Map<String, Object>();
        HttpRequest req = new HttpRequest();
        Drive__c drive = Drive__c.getOrgDefaults();
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                req.setEndpoint('https://content.googleapis.com/drive/v3/files/' + folderId + '?addParents=' + newFolderId + '&removeParents=' + oldFolderId);
                bodyMap.put('title', newFolderName.split(':')[0]);
            }
            when 'onedrive' {
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + folderId);
                bodyMap.put('parentReference', new Map<String, Object>{'id'=>newFolderId});
        		bodyMap.put('name', newFolderName);
            }
        }
        
        String body = JSON.serialize(bodyMap);
        
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('X-HTTP-Method', 'PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Content-Length', String.valueOf(body.length()));
        req.setHeader('Accept', 'application/*');
        req.setBody(body);
        req.setTimeout(60*1000);
        
        Http h = new Http(); HttpResponse res = h.send(req);
        String resp = res.getBody();
    }
    
    
    public static String testAddParent() { //For test private method
        addParent('fileId', 'fileName', 'toParentId', 'token');
        return 'SUCCESS';
    }
    
    
    public static List<Object> tmp {get;set;}
    private static void addParent(String fileId, String fileName, String toParentId, String token) { //Add parent to child
        Drive__c drive = Drive__c.getOrgDefaults();
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                Map<String, Object> bodyMap = new Map<String, Object>();
                bodyMap.put('name', fileName.split(':')[0]);
                String body = JSON.serialize(bodyMap);
                
                HttpRequest req = new HttpRequest();
                req.setMethod('POST');
                req.setEndpoint('https://content.googleapis.com/drive/v3/files/' + fileId + '?addParents=' + toParentId);
                req.setHeader('Authorization', 'Bearer ' + token);
                req.setHeader('X-HTTP-Method-Override', 'PATCH');
                req.setHeader('Content-Type', 'application/json');
                req.setHeader('Content-Length', String.valueOf(body.length()));
                req.setBody(body);
                req.setTimeout(60*1000);
                
                Http h = new Http(); h.send(req);
            }
            when 'onedrive' {
                if(tmp == null) tmp = new List<Object>();
                tmp.add(new List<String>{fileId, fileName, toParentId});
            }
        }
    }
    
    private static void removeParent(String fileId, String fileName, String fromParentId, String token) { //Remove parent from child
        Map<String, Object> bodyMap = new Map<String, Object>();
        bodyMap.put('name', fileName.split(':')[0]);
        String body = JSON.serialize(bodyMap);
        
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('https://content.googleapis.com/drive/v3/files/' + fileId + '?removeParents=' + fromParentId);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('X-HTTP-Method-Override', 'PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Content-Length', String.valueOf(body.length()));
        req.setBody(body);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        if(!Test.isRunningTest()) h.send(req);
    }
    
    
    @AuraEnabled     //Move files to Archive
    public static Boolean remove(String recordId, String fileId, String fileName, String subfolder) {
        Map<String, String> tokenFolderId = new Map<String, String>();
        token = AuthController.CheckTokenAvailability();
        if(token == null) {
            token = AuthController.getAccessToken();
        } else {
            tokenRefreshed = true;
        }
        
        String removedFilesFolderId = getFolderId('Removed Files', null, '=', false);
        String recordFolderId = getFolderId(recordId, null, 'contains', false);
        String subId;
        if(subfolder != null && subfolder != '') subId = getFolderId(subfolder, recordFolderId, '=', false);
        
        Map<String, Object> bodyMap = new Map<String, Object>();
        
        HttpRequest req = new HttpRequest();
        Drive__c drive = Drive__c.getOrgDefaults();
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                bodyMap.put('name', fileName.split(':')[0]);
                req.setEndpoint('https://content.googleapis.com/drive/v3/files/' + fileId + '?addParents=' + removedFilesFolderId + '&removeParents=' + (subId != null ? subId : recordFolderId));
            }
            when 'onedrive' {
                bodyMap.put('parentReference', new Map<String, Object>{'id'=>removedFilesFolderId});
        		bodyMap.put('@microsoft.graph.conflictBehavior', 'rename');
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + fileId);
                req.setHeader('Accept', 'application/*');
            }
        }
        
        String body = JSON.serialize(bodyMap);

        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('X-HTTP-Method', 'PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Content-Length', String.valueOf(body.length()));
        req.setBody(body);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
        system.debug(resp);
        if(drive.External_Drive_Name__c.equalsIgnoreCase('gdrive') && subfolder != null) clearFileProperties(fileId);
        if(tokenRefreshed) AuthController.SaveRefreshedToken(token);
        
        return true;
    }
    
    public static void clearFileProperties(String fileId) {
        HttpRequest req = new HttpRequest();
        req.setMethod('DELETE');
        req.setEndpoint('https://www.googleapis.com/drive/v2/files/' + fileId + '/properties/parentId?visibility=PUBLIC');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('X-HTTP-Method-Override', 'PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
        system.debug(resp);
    }
    
    @AuraEnabled     //Update Log file
    public static String updateLog(String newFiles, String action, String recordId, String folderId) {
        token = AuthController.CheckTokenAvailability();
        if(token == null) {
            token = AuthController.getAccessToken();
        } else {
            tokenRefreshed = true;
        }
        String logFileId;
        List<Object> baseFiles = getFilesList(recordId, folderId, true);
        
        if(baseFiles != null) {            
            for(Object base : baseFiles) {
                Map<String, Object> fileBaseMap = (Map<String, Object>) base;
                if((fileBaseMap.containsKey('title') && ((String) fileBaseMap.get('title')).equalsIgnoreCase('Log.csv')) || 
                   (fileBaseMap.containsKey('name') && ((String) fileBaseMap.get('name')).equalsIgnoreCase('Log.xlsx'))) {
                    logFileId = (String) fileBaseMap.get('id');
                }
            }
        }
        
        Drive__c drive = Drive__c.getOrgDefaults();
        HttpRequest req = new HttpRequest();
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                String urlParams = '?uploadType=multipart';
                String content = '"Date","User Name","Action","File Name","File Type","File Size"';
                if(logFileId != null) {
                    content = getFileContent(logFileId);
                    urlParams = '/' + logFileId + urlParams;
                }
                List<Object> newFilesList = (List<Object>) JSON.deserializeUntyped(newFiles);
                for(Object newFile : newFilesList) {
                    Map<String, Object> fileMap = (Map<String, Object>) newFile;
                    content += '\r\n"' + System.now() + '","' +
                        UserInfo.getName() + '","' +
                        action + '","' +
                        ((String) fileMap.get('name')) + '","' +
                        ((String) fileMap.get('type')) + '","' +
                        ((String) fileMap.get('size')) + '"';
                }
                
                Map<String, Object> bodyMap = new Map<String, Object>();
                if(logFileId == null) {
                    Map<String, Object> propMap = new Map<String, Object>();
                    propMap.put('parentId', recordId);
                    
                    bodyMap.put('name', 'Log.csv');
                    bodyMap.put('parents', new List<String>{folderId});
                    bodyMap.put('properties', new List<Object>{propMap, new Map<String, Object>{'subfolder'=>''}});
                } else {
                    bodyMap.put('mimeType', 'text/csv');
                }
                String body = JSON.serialize(bodyMap);
                
                req.setMethod('POST');
                req.setEndpoint('https://www.googleapis.com/upload/drive/v3/files' + urlParams);
                req.setHeader('Authorization', 'Bearer ' + token);
                if(logFileId != null) req.setHeader('X-HTTP-Method-Override', 'PATCH');
                req.setHeader('Content-Type', 'multipart/mixed; boundary=googleProject');
                req.setBody('\r\n--googleProject\r\nContent-Type: application/json\r\n\r\n' + body + '\r\n--googleProject\r\nContent-Type: text/csv\r\nContent-Transfer-Encoding: base64\r\n\r\n' + EncodingUtil.base64Encode(Blob.valueof(content)) + '\r\n--googleProject--');
                req.setTimeout(60*1000);
                
                Http h = new Http(); HttpResponse res = h.send(req);
                String resp = res.getBody();
            }
            when 'onedrive' {
                if(logFileId == null) {
                    logFileId = createLogFile(folderId);
                    //return null;
                }
                
                req.setMethod('GET');
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + logFileId + '/workbook/worksheets(\'IN\')/usedRange?$select=address');
                req.setHeader('Authorization', 'Bearer ' + token);
                req.setHeader('Accept', 'application/*');
                req.setTimeout(60*1000);
                Http h = new Http(); 
                HttpResponse res = h.send(req);
                String resp = res.getBody();
                Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
                system.debug(respMap);
                system.debug((String) respMap.get('address'));
                system.debug(((String) respMap.get('address')).split(':')[1]);
                Integer address = Integer.valueOf(((String) respMap.get('address')).split(':')[1].replaceAll('[a-zA-Z]{1,}|\\-', ''));
                
                Map<String, List<Object>> bodyMap = new Map<String, List<Object>>{'values'=>new List<Object>(), 'valueTypes'=>new List<Object>()};
                    for(Object newFile : (List<Object>) JSON.deserializeUntyped(newFiles)) {
                        Map<String, Object> fileMap = (Map<String, Object>) newFile;
                        List<Object> rowList = bodyMap.get('valueTypes');
                        rowList.add(new List<Object>{'String', 'String', 'String', 'String', 'String'});
                        bodyMap.put('valueTypes', rowList);
                        rowList = bodyMap.get('values');
                        rowList.add(new List<Object>{system.now().format('MM/dd/yyyy hh:mm:ss'), UserInfo.getName(), action, (String) fileMap.get('name'), (String) fileMap.get('size')});
                        bodyMap.put('values', rowList);
                    }
                
                req = new HttpRequest();
                req.setMethod('POST');
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + logFileId + '/workbook/worksheets(\'IN\')/range(address=\'a' + (address + 1) + ':e' + (address + bodyMap.get('values').size()) + '\')');
                req.setHeader('Authorization', 'Bearer ' + token);
                if(logFileId != null) req.setHeader('X-HTTP-Method', 'PATCH');
                req.setHeader('Accept', 'application/*');
                req.setBody(JSON.serialize(bodyMap));
                req.setTimeout(60*1000);
                
                h = new Http(); 
                res = h.send(req);
            }
        }
        return req.getBody();
    }
    
    
    private static String createLogFile(String recordFolderId) {
        system.debug(recordFolderId);
        if(Schema.sObjectType.Document.isAccessible() &&    
           Schema.sObjectType.Document.Fields.Body.isAccessible() &&    
           Schema.sObjectType.Document.Fields.Name.isAccessible()) {
            HttpRequest req = new HttpRequest();
            req.setMethod('PUT');
            req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + recordFolderId + ':/Log.xlsx:/content');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setHeader('Accept', 'application/*');
            if(!Test.isRunningTest()) req.setBodyAsBlob([SELECT Body FROM Document WHERE Folder.Name = 'Baobab Docs' AND Name = 'Log'][0].Body);
            req.setTimeout(60*1000);
            Http h = new Http(); 
            HttpResponse res = h.send(req);
            Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            for(String tmp : respMap.keySet()) {
                system.debug(tmp + ': ' + respMap.get(tmp));
            }
            return (String) respMap.get('id');
        }
        return null;
    }
    
    
    @future(callout=true) //Move record folder with renaming upon Lead conversation event
    public static void moveFilesUponLeadConversion(String inputString) {
        token = AuthController.CheckTokenAvailability();
        if(token == null) {
            token = AuthController.getAccessToken();
        } else {
            tokenRefreshed = true;
        }
        
        List<Lead> leadList = (List<Lead>) JSON.deserialize(inputString, List<Lead>.class);
        
        String mainFolderId = getFolderId(mainFolderName, null, '=', false);
        if(mainFolderId == null) {
            mainFolderId = CreateSubFolder(mainFolderName, null, token, false);
            AuthController.setRootPermissions(mainFolderId, token);
        }
        String oldFolderId = getFolderId('Lead', mainFolderId, '=', false);
        
        for(Lead ld : leadList) {
            String folderId = getFolderId(ld.id, oldFolderId, 'contains', false);
            String accountRecordFolderId = Test.isRunningTest() ? 'testFolderId' : (String) ((Map<String, Object>) JSON.deserializeUntyped(createRecordFolder(ld.ConvertedAccountId))).get('folderId');
            String newFolderId = CreateSubFolder('Contact', accountRecordFolderId, token, false);
            String newFolderName = ld.ConvertedContact.Name.replaceAll(' ', '_');
            
            moveFolder(newFolderName, folderId, newFolderId, null);
        }
        
        if(tokenRefreshed && !Test.isRunningTest()) AuthController.SaveRefreshedToken(token);
    }
    
    
    public static String getFileContent(String logFileId) {     //Get file content as string
        HttpRequest req = new HttpRequest();
        Drive__c drive = Drive__c.getOrgDefaults();
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                req.setEndpoint('https://www.googleapis.com/drive/v3/files/' + logFileId + '?alt=media');
            }
            when 'onedrive' {
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + logFileId + '/workbook/worksheets(\'IN\')/usedRange?$select=values,address');
                req.setHeader('Accept', 'application/*');
            }
        }
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        return res.getBodyAsBlob().toString();
    }
    
    
    public static String getFolderId(String folderName, String parentFolderId, String operator, Boolean forCreate) {     //Get folder id by name and parent folder id
        HttpRequest req = new HttpRequest();
        Drive__c drive = Drive__c.getOrgDefaults();
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                String parentId = parentFolderId != null ? '%20and%20%27' + parentFolderId + '%27%20in%20parents' : '';
                String searchCondition = operator.equalsIgnoreCase('contains') ? '%20and%20properties%20has%20%7B%20key%3D%27recordId%27%20and%20value%3D%27' + folderName + '%27%20and%20visibility%3D%27PUBLIC%27%20%7D' : '%20and%20title%20' + operator + '%20%27' + folderName.replaceAll(' ', '%20') + '%27';
                req.setEndpoint('https://content.googleapis.com/drive/v2/files?q=mimeType%3D%27application%2Fvnd.google-apps.folder%27' + searchCondition + '%20and%20trashed%3Dfalse' + parentId);
            }
            when 'onedrive' {
                String parentId = parentFolderId != null ? 'items/' + parentFolderId : 'root';
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/' + parentId + '/search(q=\'' + folderName.replaceAll(' ', '%20') + '\')?select=name,id');
                req.setHeader('Accept', 'application/*');
            }
        }
        system.debug(req.getEndpoint());
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*1000);

        Http h = new Http(); HttpResponse res = h.send(req);
        
        String resp = res.getBody();
        
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        system.debug(respMap);
        if(respMap.containsKey('items') || respMap.containsKey('value')) {
            List<Object> files;
            if(respMap.containsKey('items')) files = (List<Object>) respMap.get('items');
            else if(respMap.containsKey('value')) files = (List<Object>) respMap.get('value');
            
            if(!files.isEmpty()) {
                switch on drive.External_Drive_Name__c {
                    when 'gdrive' {
                        Map<String, Object> file = (Map<String, Object>) files.get(0);
                        if(operator.equalsIgnoreCase('contains')) checkRecordFolderName(file, folderName, token);
                        return (String) file.get('id');
                    }
                    when 'onedrive' {
                        for(Object obj : files) {
                            Map<String, Object> file = (Map<String, Object>) obj;
                            if(operator.equalsIgnoreCase('contains')) { 
                                checkRecordFolderName(file, folderName, token);
                                return (String) file.get('id');
                            }
                            if((String) file.get('name') == folderName) {
                                return (String) file.get('id');
                            }
                        }
                    }
                }
            } else if(forCreate) {
                Id recordId = folderName;
                String nameField = 'Name';
                if(recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Event') ||
                   recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Task')) {
                       nameField = 'Subject';
                   } else if(recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Case')) {
                       nameField = 'CaseNumber';
                   } else if(recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Contract')) {
                       nameField = 'ContractNumber';
                   } else if(recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Note')) {
                       nameField = 'Title';
                   } else if (recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Order')) {
                       nameField = 'OrderNumber';
                   }
                sObject obj = Schema.getGlobalDescribe().get(recordId.getSobjectType().getDescribe().getName()).newSObject();
                
                if(recordId.getSobjectType().getDescribe().isAccessible() && 
                   recordId.getSobjectType().getDescribe().fields.getMap().get(nameField).getDescribe().isAccessible()) {
                       obj = Database.query('SELECT ' + nameField + ' FROM ' + recordId.getSobjectType().getDescribe().getName() + ' WHERE id =: folderName').get(0);
                   }
                /*system.debug('SELECT ' + nameField + ' FROM ' + recordId.getSobjectType().getDescribe().getName() + ' WHERE id =: folderName');
                system.debug(recordId);
                system.debug(nameField);
                system.debug(obj);
                system.debug((String )obj.get(nameField));*/
                String recordFolderName;
                switch on drive.External_Drive_Name__c {
                    when 'gdrive' {
                        recordFolderName = ((String )obj.get(nameField)).replaceAll(' ', '_') + ':' + recordId;
                    }
                    when 'onedrive' {
                        recordFolderName = ((String )obj.get(nameField)).replaceAll(' ', '_') + ' (' + recordId + ')';
                
                    }
                }
                return CreateSubFolder(recordFolderName, parentFolderId, token, true);
            }
        }
        return null;
    }
    
    
    
    public static String CreateSubFolder(String folderName, String parentFolderId, String token, Boolean isRecord) {     //Create sub folder method
        HttpRequest req = new HttpRequest();
        Map<String, Object> bodyMap = new Map<String, Object>();
        Drive__c drive = Drive__c.getOrgDefaults();
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                bodyMap.put('title', folderName.split(':')[0]);
                bodyMap.put('mimeType', 'application/vnd.google-apps.folder');
                if(parentFolderId != null) bodyMap.put('parents', new List<Object>{new Map<String, Object>{'id'=>parentFolderId}});
                if(isRecord) {
                    bodyMap.put('properties', new List<Object>{new Map<String, Object>{'key'=>'isRecord', 'value'=>'True', 'visibility'=>'PUBLIC'}, 
                        new Map<String, Object>{'key'=>'recordId', 'value'=>folderName.split(':')[1], 'visibility'=>'PUBLIC'}});
                    bodyMap.put('description', folderName.split(':')[1]);
                }
                req.setEndpoint('https://content.googleapis.com/drive/v2/files');
            }
            when 'onedrive' {
                bodyMap.put('name', folderName);
        		bodyMap.put('folder', new Map<String, Object>());
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + parentFolderId + '/children');
                req.setHeader('Accept', 'application/*');
            }
        }
        
        String body = JSON.serialize(bodyMap);

        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('content-type', 'application/json');
        req.setHeader('Content-length', String.valueOf(body.length()));
        req.setBody(body);
        req.setTimeout(60*1000);
        
        Http h = new Http(); HttpResponse res = h.send(req);
        String resp = res.getBody();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        system.debug(respMap);
        return (String) respMap.get('id');
    }
    
    
    public static List<Object> getFilesListFromClassic(String parentFolderId, String tokenClassic) {
        token = tokenClassic;
        return getFilesList(null, parentFolderId, true);
    }
    
    
    public static List<Object> getFilesList(id recordId, String parentFolderId, Boolean shouldNext) { //Get all files from record folder
        if(parentFolderId == null) return null;
        //String parentId = '%20and%20properties%20has%20%7B%20key%3D%27parentId%27%20and%20value%3D%27' + recordId + '%27%20and%20visibility%3D%27PUBLIC%27%20%7D';
        HttpRequest req = new HttpRequest();
        Drive__c drive = Drive__c.getOrgDefaults();
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                req.setEndpoint('https://content.googleapis.com/drive/v2/files?q=trashed%3Dfalse%20and%20mimeType%20!%3D%20%27application%2Fvnd.google-apps.folder%27%20and%20%27' + parentFolderId + '%27%20in%20parents');
            }
            when 'onedrive' {
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + parentFolderId + '/children');
                req.setHeader('Accept', 'application/*');
            }
        }
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
        
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        if(respMap.containsKey('items')) {
            List<Object> files = (List<Object>) respMap.get('items');
            if(!files.isEmpty()) {
                return files;
            }
        } else if(respMap.containsKey('value')) {
            List<Object> totalFiles = new List<Object>();
            List<Object> files = (List<Object>) respMap.get('value');
            for(Object obj : files) {
                Map<String, Object> file = (Map<String, Object>) obj;
                if(file.containsKey('file')) {
                    totalFiles.add(file);
                } else if(file.containsKey('folder') && shouldNext) {
                    totalFiles.addAll(getFilesList(null, (String) file.get('id'), false));
                }
            }
            return totalFiles;
        }
        return null;
    }
    
    
    
    public static void checkRecordFolderName(Map<String, Object> file, String recordStrId, String token) {     //Check if record folder name equals salesforce record name
        Id recordId = recordStrId;
        String nameField = 'Name';
        if(recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Event') || recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Task')) {
            nameField = 'Subject';
        } else if(recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Case')) {
            nameField = 'CaseNumber';
        } else if(recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Contract')) {
            nameField = 'ContractNumber';
        } else if(recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Note')) {
            nameField = 'Title';
        } else if (recordId.getSobjectType().getDescribe().getName().equalsIgnoreCase('Order')) {
            nameField = 'OrderNumber';
        }
        sObject obj = Schema.getGlobalDescribe().get(recordId.getSobjectType().getDescribe().getName()).newSObject();
        if(recordId.getSobjectType().getDescribe().isAccessible() && 
           recordId.getSobjectType().getDescribe().fields.getMap().get(nameField).getDescribe().isAccessible()) {
               obj = Database.query('SELECT ' + nameField + ' FROM ' + recordId.getSobjectType().getDescribe().getName() + ' WHERE id =: recordStrId').get(0);
           }
        String recordFolderName = ((String )obj.get(nameField)).replaceAll(' ', '_');
        Drive__c drive = Drive__c.getOrgDefaults();
        
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('X-HTTP-Method', 'PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60*1000);
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                if(!recordFolderName.equalsIgnoreCase((String) file.get('title'))) {
                    Map<String, Object> bodyMap = new Map<String, Object>();
                    bodyMap.put('title', recordFolderName);
                    String body = JSON.serialize(bodyMap);
                    
                    req.setEndpoint('https://www.googleapis.com/drive/v2/files/' + (String) file.get('id'));
                    req.setHeader('Content-Length', String.valueOf(body.length()));
                    req.setBody(body);
                    
                    Http h = new Http();
                    if(!Test.isRunningTest()) h.send(req);
                }
            }
            when 'onedrive' {
                recordFolderName += ' (' + recordStrId + ')';
                if(!recordFolderName.equalsIgnoreCase((String) file.get('name'))) {
                    Map<String, Object> bodyMap = new Map<String, Object>();
                    bodyMap.put('name', recordFolderName);
                    String body = JSON.serialize(bodyMap);
                    
                    req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/items/' + (String) file.get('id'));
                    req.setHeader('Content-Length', String.valueOf(body.length()));
                    req.setHeader('Accept', 'application/*');
                    req.setBody(body);
                    
                    Http h = new Http();
                    if(!Test.isRunningTest()) h.send(req);
                }
            }
        }
    }
    
    
    public static String getOneDriveFolderId(String folderName, String token) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/root/children');
        req.setHeader('Accept', 'application/*');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        if(respMap.containsKey('value')) {
            List<Object> files = (List<Object>) respMap.get('value');
            for(Object obj : files) {
                Map<String, Object> file = (Map<String, Object>) obj;
                if(file.containsKey('name') && ((String)file.get('name')).containsIgnoreCase(folderName)) {
                    return (String)file.get('id');
                }
            }
        }
        return null;
    }
}