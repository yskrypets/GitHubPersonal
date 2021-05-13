public with sharing class AuthController {
    public static String code{get;set;} 
    public static final Drive_Setting__mdt googleDrivedKeys = [SELECT Client_ID__c, Client_Secret__c FROM Drive_Setting__mdt WHERE MasterLabel = 'Google Drive Key' LIMIT 1][0];
	public static final Drive_Setting__mdt oneDrivedKeys = [SELECT Client_ID__c, Client_Secret__c FROM Drive_Setting__mdt WHERE MasterLabel = 'OneDrive Key' LIMIT 1][0];
    public static final String redirect_uri = URL.getSalesforceBaseUrl().toExternalForm() + '/apex/GoogleDrivePage'; 
    public static final String redirector_uri = EncodingUtil.urlEncode('https://baobabmiscpublic.s3.amazonaws.com/BaobabGoogleDriveRedirector/index.html','UTF-8');
    public static final String mainFolderName = 'Salesforce Root'; 
    private static String mainFolderId = 'root';
    private static final Set<String> blackList = new Set<String>{'channelprogram', 'channelprogramlevel', 'commsubscription', 'commsubscriptionchanneltype', 'commsubscriptionconsent', 'commsubscriptiontiming', 
		'delegatedaccount', 'emailmessage', 'emailtemplate', 'engagementchanneltype', 'partnerfundallocation', 'partnerfundclaim', 'partnerfundrequest', 'partnermarketingbudget', 'workcoaching', 
		'drive_object__c', 'drive__c', 'subfolder__c', 'log__c'};
    public static final Map<String, Schema.SObjectType> whiteList {get{
        Map<String, Schema.SObjectType> objects = new Map<String, Schema.SObjectType>();
        for(Schema.SObjectType sot : Schema.SObjectType.Attachment.Fields.ParentId.getReferenceTo()) {
            Schema.DescribeSObjectResult dor = sot.getDescribe();
            if(!blacklist.contains(dor.getName().toLowerCase()) && dor.isQueryable() && dor.isDeletable() && dor.isCreateable() && dor.isAccessible()) {
                objects.put(dor.getName().toLowerCase(), sot);
            }
        }
        return objects;
    }set;}
    
            
            
    //check code after callback from google drive authorization page
    public static PageReference codeCheck() {
        //Get the access token once we have code
        if(code != '' && code != null) {
            AccessToken(); CreateFoldersTree(); //createSetupObjects();
        }
        return new PageReference('/one/one.app?source=alohaHeader#/n/Google_Project');
    }
    
    
    //check if user authorized and have access for login/logout
    @AuraEnabled
    public static Object checkAuthorizing() {
        Map<String, Object> access = (Map<String, Object>) checkAuthorizingWithoutSave();
        if((Boolean)access.get('tokenRefreshed') && !System.isFuture() && !System.isBatch()) SaveRefreshedToken((String)access.get('token'));
        return access;
    }
    
    //check if user authorized and have access for login/logout
    @AuraEnabled
    public static Object checkAuthorizingWithoutSave() {
        Map<String, Object> access = new Map<String, Object>();
        if(Schema.sObjectType.Profile.isAccessible() &&
           Schema.sObjectType.Profile.Fields.PermissionsViewSetup.isAccessible()) {
               if(FeatureManagement.checkPermission('Google_Project_Logout') ||
                  [SELECT PermissionsViewSetup FROM Profile WHERE id =: UserInfo.getProfileId()].PermissionsViewSetup) {
                      access.put('access', true);
                  }
           }
        String token;
        access.put('tokenRefreshed', false);
        access.put('auth', false);
        try {
            token = CheckTokenAvailability();
            if(token == null) {
                token = getAccessToken();
            } else {
                access.put('tokenRefreshed', true);
            }
            access.put('token', token);
        } catch(Exception e) {
            system.debug(e);
            return access;
        }
        
        if(token != null) access.put('auth', true); 
        return access;
    }
    
    
    
    @AuraEnabled //redirect user to google drive authorization page
    public static String authDrive(String externalDriveName) {
        if(Schema.sObjectType.Drive__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.External_Drive_Name__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.External_Drive_Name__c.isCreateable()) {
               Drive__c drive = Drive__c.getOrgDefaults();
               drive.External_Drive_Name__c = externalDriveName;
               upsert drive;
           }
        switch on externalDriveName {
            when 'gdrive' {
                return GoogleDriveAuthUri(googleDrivedKeys.Client_ID__c, redirect_uri);
            }
            when 'onedrive' {
                return OneDriveAuthUri(oneDrivedKeys.Client_ID__c, redirect_uri);
            }
        }
        return null;
    }
    
    
    public static String GoogleDriveAuthUri(String Clientkey, String redirect_uri) { //create url for google drive authorization page
        String key = EncodingUtil.urlEncode(Clientkey,'UTF-8');
        String uri = EncodingUtil.urlEncode(redirect_uri,'UTF-8');
        String authuri = '';
        authuri = 'https://accounts.google.com/o/oauth2/auth?' + 
            'client_id=' + key + 
            '&response_type=code' +  
            '&scope=https://www.googleapis.com/auth/drive' +  
            '&redirect_uri=' + redirector_uri + 
            '&state=' + uri +  
            '&access_type=offline' + 
            '&approval_prompt=force';
        return authuri;
    }
    
    
    public static String OneDriveAuthUri(String Clientkey, String redirect_uri) { //create url for OneDrive authorization page
        String key = EncodingUtil.urlEncode(Clientkey,'UTF-8');
        String uri = EncodingUtil.urlEncode(redirect_uri,'UTF-8');
        String authuri = '';
        authuri = 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?' +
            'client_id=' + key + 
            '&scope=files.readwrite.all,offline_access' +
            '&response_type=code' + 
            '&redirect_uri=' + redirector_uri + 
            '&state=' + uri;
        return authuri;
    }
    
    
    public static void AccessToken() {     //change responsed CODE to Bearer Access and Refresh Tokens
        Drive__c drive = Drive__c.getOrgDefaults();
        String endPoint, messageBody;
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                endPoint = 'https://accounts.google.com/o/oauth2/token';
                messageBody = 'code=' + code + '&client_id=' + AuthController.googleDrivedKeys.Client_ID__c + '&client_secret=' + AuthController.googleDrivedKeys.Client_Secret__c + '&redirect_uri=' + redirector_uri + '&grant_type=authorization_code';
            }
            when 'onedrive' {
                endPoint = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
                messageBody = 'grant_type=authorization_code&code=' + code + '&client_id=' + AuthController.oneDrivedKeys.Client_ID__c + '&client_secret=' + AuthController.oneDrivedKeys.Client_Secret__c + '&redirect_uri=' + redirector_uri;
            }
        }
        
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(endPoint);
        req.setHeader('content-type', 'application/x-www-form-urlencoded');
        req.setHeader('Content-length', String.valueOf(messageBody.length()));
        req.setBody(messageBody);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);

        if(Schema.sObjectType.Drive__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken1__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken1__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken2__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken2__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken3__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken3__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken4__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken4__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken5__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken5__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.RefreshToken1__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.RefreshToken1__c.isCreateable() &&
           Schema.sObjectType.Drive__c.Fields.RefreshToken2__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.RefreshToken2__c.isCreateable() &&
           Schema.sObjectType.Drive__c.Fields.Files_Action__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.Files_Action__c.isCreateable() &&
           Schema.sObjectType.Drive__c.Fields.Expires_In__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.Expires_In__c.isCreateable() &&
           Schema.sObjectType.Drive__c.Fields.External_Drive_Name__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.External_Drive_Name__c.isCreateable()) {
               String tmpToken = (String) respMap.get('access_token');
               String tmpToken2 = (String) respMap.get('refresh_token');
               drive.AccessToken1__c = tmpToken.length() > 255 ? tmpToken.substring(0, 255) : tmpToken;
               if(tmpToken.length() > 255) drive.AccessToken2__c = tmpToken.length() > 510 ? tmpToken.substring(255, 510) : tmpToken.substring(255);
               if(tmpToken.length() > 510) drive.AccessToken3__c = tmpToken.length() > 765 ? tmpToken.substring(510, 765) : tmpToken.substring(510);
               if(tmpToken.length() > 765) drive.AccessToken4__c = tmpToken.length() > 1020 ? tmpToken.substring(765, 1020) : tmpToken.substring(765);
               if(tmpToken.length() > 1020) drive.AccessToken5__c = tmpToken.substring(1020);
               drive.RefreshToken1__c = tmpToken2.length() > 255 ? tmpToken2.substring(0, 255) : tmpToken2;
               if(tmpToken2.length() > 255) drive.RefreshToken2__c = tmpToken2.substring(255);
               if(drive.External_Drive_Name__c == 'onedrive') drive.Expires_In__c = system.now().addSeconds((Integer) respMap.get('expires_in') - 600);	//Expires time minus 10 minutes
               drive.Files_Action__c = 'nothing';
               upsert drive;
           }
    }
    
    
    
    public static String getAccessToken() {
        Drive__c drive = Drive__c.getOrgDefaults();
        if(drive.AccessToken1__c == null) return null;
        String tokenForReturn = drive.AccessToken1__c + (drive.AccessToken2__c == null ? '' : drive.AccessToken2__c + drive.AccessToken3__c + drive.AccessToken4__c + drive.AccessToken5__c);
		return tokenForReturn;        
    }
    
    
    
    public static String getRefreshToken() {
		Drive__c drive = Drive__c.getOrgDefaults();
        if(drive.RefreshToken1__c == null) return null;
        String tokenForReturn = drive.RefreshToken1__c + drive.RefreshToken2__c;
		return tokenForReturn;        
    }
    
    
    
    public static String CheckTokenAvailability() { //Check if Access Token is still available, if not call refresh method
        Drive__c drive = Drive__c.getOrgDefaults();
        
        if(drive.External_Drive_Name__c == 'gdrive') {
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint('https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=' + drive.AccessToken1__c);
            req.setTimeout(60*1000);
            
            Http h = new Http();
            HttpResponse res = h.send(req);
            String resp = res.getBody();
            Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
            
            if(respMap.containsKey('expires_in')) {
                Integer expires = (Integer) respMap.get('expires_in');
                if(expires <= 600) return RefreshAccessToken();
            }
            if(respMap.containsKey('error')) return RefreshAccessToken();
        } else if(drive.External_Drive_Name__c == 'onedrive') {
            if(drive.Expires_In__c <= system.now()) {
                return Test.isRunningTest() ? 'testaccesstoken' : RefreshAccessToken();
            }
        } else if(Test.isRunningTest()) {
            return 'testaccesstoken';
        }
        return null;
    }
    
    
    private static String RefreshAccessToken() {//method for refresh Access Token
        Drive__c drive = Drive__c.getOrgDefaults();
        String endPoint, messageBody;
        switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                endPoint = 'https://accounts.google.com/o/oauth2/token';
                messageBody = 'client_id=' + googleDrivedKeys.Client_ID__c + '&client_secret=' + googleDrivedKeys.Client_Secret__c + '&refresh_token=' + Drive__c.getOrgDefaults().RefreshToken1__c + '&grant_type=refresh_token';
            }
            when 'onedrive' {
                endPoint = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
                messageBody = 'grant_type=refresh_token&refresh_token=' + getRefreshToken() + '&client_id=' + oneDrivedKeys.Client_ID__c + '&client_secret=' + oneDrivedKeys.Client_Secret__c + '&redirect_uri=' + redirector_uri;
            }
        }
        
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(endPoint);
        req.setHeader('content-type', 'application/x-www-form-urlencoded');
        req.setHeader('Content-length', String.valueOf(messageBody.length()));
        req.setBody(messageBody);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);

        if(respMap.containsKey('error')) { throw new authException('You need to reauthorize to External Drive'); }
        
        return (String) respMap.get('access_token');
    }
    
       
    @future //Save refreshed Access Token 
    public static void SaveRefreshedToken(String token) {
        Drive__c drive = Drive__c.getOrgDefaults();
        if(Schema.sObjectType.Drive__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken1__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken1__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken2__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken2__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken3__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken3__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken4__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken4__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken5__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken5__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.RefreshToken1__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.RefreshToken1__c.isCreateable() &&
           Schema.sObjectType.Drive__c.Fields.RefreshToken2__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.RefreshToken2__c.isCreateable() &&
           Schema.sObjectType.Drive__c.Fields.Files_Action__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.Files_Action__c.isCreateable() &&
           Schema.sObjectType.Drive__c.Fields.Expires_In__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.Expires_In__c.isCreateable() &&
           Schema.sObjectType.Drive__c.Fields.External_Drive_Name__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.External_Drive_Name__c.isCreateable()) {
               drive.AccessToken1__c = token.length() > 255 ? token.substring(0, 255) : token;
               if(token.length() > 255) drive.AccessToken2__c = token.length() > 510 ? token.substring(255, 510) : token.substring(255);
               if(token.length() > 510) drive.AccessToken3__c = token.length() > 765 ? token.substring(510, 765) : token.substring(510);
               if(token.length() > 765) drive.AccessToken4__c = token.length() > 1020 ? token.substring(765, 1020) : token.substring(765);
               if(token.length() > 1020) drive.AccessToken5__c = token.substring(1020);
               if(drive.External_Drive_Name__c == 'onedrive') drive.Expires_In__c = system.now().addSeconds(3000);
               upsert drive;
           }
    }
    
    
    
    @AuraEnabled //Log Out from Google Drive
    public static void logOutDrive() {
        Drive__c drive = Drive__c.getOrgDefaults();
        if(Schema.sObjectType.Drive__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken1__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken1__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken2__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken2__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken3__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken3__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken4__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken4__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken5__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.AccessToken5__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.RefreshToken1__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.RefreshToken1__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.RefreshToken2__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.RefreshToken2__c.isCreateable() && 
           Schema.sObjectType.Drive__c.Fields.Expires_In__c.isUpdateable() && 
           Schema.sObjectType.Drive__c.Fields.Expires_In__c.isCreateable()) {
               drive.AccessToken1__c = null;
               drive.AccessToken2__c = null;
               drive.AccessToken3__c = null;
               drive.AccessToken4__c = null;
               drive.AccessToken5__c = null;
               drive.RefreshToken1__c = null;
               drive.RefreshToken2__c = null;
               drive.Expires_In__c = null;
               upsert drive;
           }
    }
    
    
    
    
    @AuraEnabled //Clear Deleted records from Drive
    public static String clearDeleted() {
        Boolean tokenRefreshed = false;
        String token = CheckTokenAvailability();
        if(token == null) {
            token = AuthController.getAccessToken();
        } else {
            tokenRefreshed = true;
        }
        Database.executeBatch(new ClearDeletedIterable(token), 50);
        
        if(tokenRefreshed && !System.isFuture() && !System.isBatch()) SaveRefreshedToken(token);
        
        return 'SUCCESS';
    }
    
    
    @AuraEnabled //Clear Archived folder
    public static String clearArchivedFolder() {
        Boolean tokenRefreshed = false; 
        String token = CheckTokenAvailability();
        if(token == null) {
            token = AuthController.getAccessToken();
        } else {
            tokenRefreshed = true;
        }

        mainFolderId = getFolderId(mainFolderName, null, token);
        String archivedFolderId = getFolderId('Archived', mainFolderId, token);
        if(archivedFolderId != null) FoldersListController.DeleteFolder(archivedFolderId, token);
        archivedFolderId = FilesController.CreateSubFolder('Archived', mainFolderId, token, false);
        FilesController.CreateSubFolder('Removed Files', archivedFolderId, token, false);
        FilesController.CreateSubFolder('Removed Records', archivedFolderId, token, false);
        
        if(tokenRefreshed && !System.isFuture() && !System.isBatch()) SaveRefreshedToken(token);
        
        return 'SUCCESS';
    }
    
    
    
    //Create Salesforce Root folder and Base folders tree
    public static void CreateFoldersTree() {
        Database.executeBatch(new CreateFoldersTreeBatch(), 50);
    }
    
    
    public static void setRootPermissions(String rootId, String token) { //Set permissions for root
        if(!Drive__c.getOrgDefaults().External_Drive_Name__c.equalsIgnoreCase('gdrive')) return;
        
        Map<String, Object> bodyMap = new Map<String, Object>();
        bodyMap.put('role', 'writer'); 
        bodyMap.put('type', 'anyone');
        String body = JSON.serialize(bodyMap);
        
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('https://content.googleapis.com/drive/v3/files/' + rootId + '/permissions?alt=json');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('content-type', 'application/json');
        req.setHeader('Content-length', String.valueOf(body.length()));
        req.setBody(body);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
    }
    
    
    public static String CreateSubFolder(String devName, String folderName, String parentFolderId, String token) {     //Create sub folder method
        Drive__c drive = Drive__c.getOrgDefaults();
        String endPoint, messageBody;
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
                endPoint = 'https://content.googleapis.com/drive/v2/files';
                messageBody = JSON.serialize(new Map<String, Object>{'title'=>folderName, 'mimeType'=>'application/vnd.google-apps.folder', 'parents'=>new List<Object>{new Map<String, Object>{'id'=>(parentFolderId == null ? mainFolderId : parentFolderId)}}});
            }
            when 'onedrive' {
                endPoint = 'https://graph.microsoft.com/v1.0/me/drive/items/' + EncodingUtil.urlEncode((parentFolderId == null ? mainFolderId : parentFolderId),'UTF-8') + '/children';
                messageBody = JSON.serialize(new Map<String, Object>{'name'=>folderName, 'folder'=>new Map<String, Object>()});
            }
        }
        system.debug(endPoint);
        
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(endPoint);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'application/*');
        req.setHeader('content-type', 'application/json');
        req.setHeader('Content-length', String.valueOf(messageBody.length()));
        req.setBody(messageBody);
        req.setTimeout(60*1000);
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String resp = res.getBody();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(resp);
        system.debug(respMap);
        return (String) respMap.get('id');
    }
    
    
    /*public static void createSetupObjects() {    //Create setup Objects
        List<Drive_Object__c> doList;
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible()) {
            doList = [SELECT id, Name FROM Drive_Object__c LIMIT 50000];
        } else {
            return;
        }
        
        List<Drive_Object__c> doListForCreate = new List<Drive_Object__c>();
        Set<String> doNames = new Set<String>();
        
        for(Drive_Object__c dob : doList) {
            doNames.add(dob.Name.toLowerCase());
        }

        if(Schema.sObjectType.Drive_Object__c.isCreateable() && 
           Schema.sObjectType.Drive_Object__c.Fields.Name.isCreateable() &&
           Schema.sObjectType.Drive_Object__c.Fields.Label__c.isCreateable() &&
           Schema.sObjectType.Drive_Object__c.Fields.isCreated__c.isCreateable()) {
            for(String objName : whiteList.keySet()) {
                if(!doNames.contains(objName)) doListForCreate.add(new Drive_Object__c(Name=whiteList.get(objName).getDescribe().getName(), Label__c=whiteList.get(objName).getDescribe().getLabel(), isCreated__c=true));
            }
            
            if(!doListForCreate.isEmpty()) insert doListForCreate;
        }
    }*/
    
    
    public static String getFolderId(String folderName, String parentFolderId, String token) {     //Get folder id from Google Drive by name and parent folder id
        Drive__c drive = Drive__c.getOrgDefaults();
        HttpRequest req = new HttpRequest();
        String endPoint;
        String parentId = '';
        if(parentFolderId != null) parentId = '%20and%20%27' + parentFolderId + '%27%20in%20parents';
		switch on drive.External_Drive_Name__c {
            when 'gdrive' {
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

        Http h = new Http();
        HttpResponse res = h.send(req);
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
                	if((String) file.get('name') == folderName) return (String) file.get('id');
                }
            }
        }
        return null;
    }
    
    
    public class authException extends Exception {} //Custom Exception
}