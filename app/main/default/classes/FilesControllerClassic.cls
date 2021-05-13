global with sharing class FilesControllerClassic {
    public String token {get;set;}
    public Boolean authorized {get;set;}
    public Boolean available {get;set;}
    public Boolean filesEmpty {get;set;}
    public String recordFolderId {get;set;}
    public static Boolean showUploadButton {get;set;}
    public String dropOpacity {get;set;}
    public String dropStyle {get;set;}
    public List<Object> files {get;set;}
    public static String subfolderName {get;set;}
    public String parentObjectLabel {get;set;}
    public String parentRecordId {get;set;}
    public String driveName {get;set;}
    
    public FilesControllerClassic() {
        authorized = false;
        showUploadButton = false;
        try {
            token = AuthController.CheckTokenAvailability();
            if(token == null) token = AuthController.getAccessToken();
        } catch(Exception e) {
            system.debug(e.getStackTraceString());
        }
        if(token != null) {
            authorized = true;
        }
        Drive__c drive = Drive__c.getOrgDefaults();
        driveName = drive.External_Drive_Name__c;
    }
    
    public Id recordId {get; set{
        recordId = value;
        dropStyle = 'z-index: -1;';
        if(Schema.sObjectType.Drive_Object__c.isAccessible() &&  
           Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() &&  
           Schema.sObjectType.Drive_Object__c.Fields.Label__c.isAccessible() &&  
           Schema.sObjectType.Drive_Object__c.Fields.isCreated__c.isAccessible() && 
           Schema.sObjectType.Drive_Object__c.Fields.Parent_Object__c.isAccessible()) {
               List<Drive_Object__c> dobList = [SELECT id, Name, Label__c, isCreated__c, Parent_Object__c FROM Drive_Object__c WHERE Name =: recordId.getSobjectType().getDescribe().getName() LIMIT 1];
               if(!dobList.isEmpty()) {
                   Drive_Object__c dob = dobList[0];
                   if(dob.isCreated__c) {
                       Drive__c drive = Drive__c.getOrgDefaults();
                       if(drive.External_Drive_Name__c.equalsIgnoreCase('onedrive') && dob.Parent_Object__c != null && Schema.getGlobalDescribe().containsKey(dob.Parent_Object__c)) {
                           parentObjectLabel = Schema.getGlobalDescribe().get(dob.Parent_Object__c).getDescribe().getLabel();
                           String parentFieldName = FilesController.getFieldName(recordId, dob.Parent_Object__c);
                           if(recordId.getSobjectType().getDescribe().isAccessible() && 
                              recordId.getSobjectType().getDescribe().fields.getMap().get(parentFieldName).getDescribe().isAccessible()) {
                                system.debug('SELECT ' + parentFieldName + ' FROM ' + recordId.getSobjectType().getDescribe().getName() + ' WHERE id = \'' + recordId + '\'');
                                parentRecordId = (String) Database.query('SELECT ' + parentFieldName + ' FROM ' + recordId.getSobjectType().getDescribe().getName() + ' WHERE id = \'' + recordId + '\'').get(0).get(parentFieldName);
                            }
                        }
                       available = true;
                       files = getDriveFiles();
                       if(files == null) {
                           filesEmpty = false;
                           dropOpacity = 'opacity:1;';
                       } else {
                           filesEmpty = true;
                           dropOpacity = 'opacity:0;';
                       }
                       return;
                   }
               }
           }
        available = false;
    }}
    
    
    private List<Object> getDriveFiles() {
        Drive__c drive = Drive__c.getOrgDefaults();
        List<Map<String, Object>> filesList = new List<Map<String, Object>>();
        List<Object> filesListForReturn = new List<Object>();
        
        Set<String> subfoldersSet = new Set<String>();
        recordFolderId = getFolderId(recordId, null, 'contains', false);
        
        List<Object> baseFiles;
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                List<SelectOption> soList = getSubfolders();
                baseFiles = getFilesList(recordFolderId);
                if(baseFiles == null) return null;
                for(SelectOption so : soList) {
                    String subfolderId = getFolderId(so.getValue(), recordFolderId, '=', false);
                    List<Object> tmpFiles = getFilesList(subfolderId);
                    if(tmpFiles != null) baseFiles.addAll(tmpFiles);
                }
            }
            when 'onedrive' {
                baseFiles = FilesController.getFilesListFromClassic(recordFolderId, token);
                if(baseFiles == null) return null;
            }
        }
        
            
        for(Object base : baseFiles) {
            Map<String, Object> fileBaseMap = (Map<String, Object>) base;
            //system.debug(drive.External_Drive_Name__c.equalsIgnoreCase('onedrive'));
            //system.debug(((String) fileBaseMap.get('name')).equalsIgnoreCase('Log.xlsx'));
            if(drive.External_Drive_Name__c.equalsIgnoreCase('gdrive') && !((String) fileBaseMap.get('title')).equalsIgnoreCase('Log.csv')) {
                Map<String, Object> fileMap = new Map<String, Object>();
                //system.debug(fileBaseMap.get('properties'));
                fileMap.put('id', fileBaseMap.get('id'));
                fileMap.put('Type', fileBaseMap.get('mimeType'));
                fileMap.put('iconLink', fileBaseMap.get('iconLink'));
                fileMap.put('Name', fileBaseMap.get('title'));
                fileMap.put('Size', fileBaseMap.get('fileSize'));
                fileMap.put('DownloadLink', fileBaseMap.get('webContentLink'));
                fileMap.put('parentId', ((Map<String, Object>)((List<Object>)fileBaseMap.get('parents'))[0]).get('id'));
                fileMap.put('Subfolder', '');
                if(fileBaseMap.containsKey('properties')) {
                    for(Object prop : (List<Object>) fileBaseMap.get('properties')) {
                        Map<String, Object> propMap = (Map<String, Object>) prop;
                        if((String)propMap.get('key') == 'subfolder') {
                            fileMap.put('Subfolder', propMap.get('value'));
                            subfoldersSet.add((String)propMap.get('value'));
                            break;
                        }
                    }
                }
                filesList.add(fileMap);
            } else if(drive.External_Drive_Name__c.equalsIgnoreCase('onedrive') && !((String) fileBaseMap.get('name')).equalsIgnoreCase('Log.xlsx')) {
                Map<String, Object> fileMap = new Map<String, Object>();
                fileMap.put('id', fileBaseMap.get('id'));
                fileMap.put('Type', ((Map<String, Object>)fileBaseMap.get('file')).get('mimeType'));
                fileMap.put('Name', fileBaseMap.get('name'));
                fileMap.put('Size', fileBaseMap.get('size'));
                fileMap.put('DownloadLink', fileBaseMap.get('@microsoft.graph.downloadUrl'));
                fileMap.put('parentId', ((Map<String, Object>)fileBaseMap.get('parentReference')).get('id'));
                fileMap.put('Subfolder', ((Map<String, Object>)fileBaseMap.get('parentReference')).get('name'));
                filesList.add(fileMap);
            }
        }

        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                List<String> subfoldersList = new List<String>();   //sorting
                subfoldersList.addAll(subfoldersSet);
                subfoldersList.sort();
                for(String str : subfoldersList) {
                    for(Map<String, Object> fileMap : filesList) {
                        if(fileMap.containsKey('Subfolder') && str.equalsIgnoreCase((String)fileMap.get('Subfolder'))) filesListForReturn.add(fileMap);
                    }
                }
            }
            when 'onedrive' {
                filesListForReturn = filesList;
            }
        }
        
        if(filesList.isEmpty()) return null;
        
        return filesListForReturn;
    }
    
    
    
    public List<SelectOption> getSubfolders() {
        id recId = recordId;
        List<SelectOption> subfolders = new List<SelectOption>{new SelectOption('', 'None')};
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Label__c.isAccessible() 
          && Schema.sObjectType.Subfolder__c.isAccessible() && Schema.sObjectType.Subfolder__c.Fields.Name.isAccessible()) {
            List<Drive_Object__c> drvObjList = [SELECT id, Name, Label__c, (SELECT id, Name FROM Subfolders__r) FROM Drive_Object__c WHERE Name =: recId.getSObjectType().getDescribe().getName() LIMIT 1];
            if(!drvObjList.isEmpty() && !drvObjList[0].Subfolders__r.isEmpty()) {
                for(Subfolder__c sub : drvObjList[0].Subfolders__r) {
                    subfolders.add(new SelectOption(sub.Name, sub.Name));
                }       
            }
        }
        return subfolders;
    }
    
    
    @RemoteAction
    global static Boolean removeFile(String recordId, String fileId, String fileName, String subfolder) {
        return FilesController.remove(recordId, fileId, fileName, subfolder);
    }
    
    @RemoteAction
    global static Boolean remove(String recordId, String fileId, String fileName) {
        return FilesController.remove(recordId, fileId, fileName, null);
    }
    
    @RemoteAction
    global static Object createRecordFolder(String recId) {
        showUploadButton = false;
        subfolderName = null;
        return JSON.deserializeUntyped(FilesController.createRecordFolder(recId));
    }
    
    @RemoteAction
    global static String updateLog(String newFiles, String action, String recId, String folderId) {
        return FilesController.updateLog(newFiles, action, recId, folderId);
    }
    
    
    public void reloadFiles() {
        files = getDriveFiles();
        if(files == null) {
            filesEmpty = false;
            dropOpacity = 'opacity:1;';
        } else {
            filesEmpty = true;
            dropOpacity = 'opacity:0;';
        }
    }
    
    
    public String getFolderId(String folderName, String parentFolderId, String operator, Boolean forCreate) {
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
                req.setEndpoint('https://graph.microsoft.com/v1.0/me/drive/' + parentId + '/search(q=\'' + folderName.replaceAll(' ', '%20') + '\')?select=name,id,parentReference');
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
        if(respMap.containsKey('items') || respMap.containsKey('value')) {
            List<Object> files;
            if(respMap.containsKey('items')) files = (List<Object>) respMap.get('items');
            else if(respMap.containsKey('value')) files = (List<Object>) respMap.get('value');
            system.debug(files);
            if(!files.isEmpty()) {
                if(drive.External_Drive_Name__c.equalsIgnoreCase('onedrive') && files.size() > 1) {
                    for(Object obj : files) {
                        Map<String, Object> file = (Map<String, Object>) obj;
                        system.debug(file);
                        Map<String, Object> parentRef = (Map<String, Object>) file.get('parentReference');
                        system.debug(parentRef);
                        String pathString = (String) parentRef.get('path');
                        system.debug(pathString);
                        system.debug(parentRecordId);
                        /*if(pathString.containsIgnoreCase(parentRecordId)) */return (String) file.get('id');
                    }
                } else {
                	Map<String, Object> file = (Map<String, Object>) files.get(0);
                	if(operator.equalsIgnoreCase('contains')) FilesController.checkRecordFolderName(file, folderName, token);
                	return (String) file.get('id');
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
                   }
                sObject obj = Schema.getGlobalDescribe().get(recordId.getSobjectType().getDescribe().getName()).newSObject();

                if(recordId.getSobjectType().getDescribe().isAccessible() && 
                   recordId.getSobjectType().getDescribe().fields.getMap().get(nameField).getDescribe().isAccessible()) {
                    obj = Database.query('SELECT ' + nameField + ' FROM ' + recordId.getSobjectType().getDescribe().getName() + ' WHERE id = \'' + folderName + '\'').get(0);
                }
                String recordFolderName = ((String )obj.get(nameField)).replaceAll(' ', '_');
                switch on drive.External_Drive_Name__c {
                    when 'gdrive' {
                        recordFolderName += ':' + recordId;
                    }
                    when 'onedrive' {
                        recordFolderName += ' (' + recordId + ')';
                    }
                }
                return FilesController.CreateSubFolder(recordFolderName, parentFolderId, token, true);
            }
        }
        return null;
    }
    
    
    public List<Object> getFilesList(String parentFolderId) {
        if(parentFolderId == null) return null;
        //String parentId = '%20and%20properties%20has%20%7B%20key%3D%27parentId%27%20and%20value%3D%27' + recordId + '%27%20and%20visibility%3D%27PUBLIC%27%20%7D';
        String parentId = '%20and%20%27' + parentFolderId + '%27%20in%20parents';
        
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint('https://content.googleapis.com/drive/v2/files?q=trashed%3Dfalse%20and%20mimeType%20!%3D%20%27application%2Fvnd.google-apps.folder%27' + parentId);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(60*1000);
        
        Http h = new Http(); HttpResponse res = h.send(req);
        
        String resp = res.getBody();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        system.debug(respMap);
        if(respMap.containsKey('items')) {
            List<Object> files = (List<Object>) respMap.get('items');
            if(!files.isEmpty()) {
                return files;
            }
        }
        return null;
    }
}