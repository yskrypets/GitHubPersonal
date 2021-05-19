public with sharing class AuthControllerClassic {
    public static String code {get;set;}
    public static final String redirect_uri = URL.getSalesforceBaseUrl().toExternalForm() + '/apex/GoogleDriveClassicPage';
    public static final String redirector_uri = AuthController.redirector_uri;
    public Boolean authorized {get;set;}
    public Boolean access {get;set;}
    public boolean displayAuthPopup {get; set;}
    public boolean displayClearPopUp {get; set;}
    public String externalDriveName {get; set;}
    
    
    public AuthControllerClassic() {
        externalDriveName = 'Authorize';
        authorized = false;
        if(Schema.sObjectType.Profile.isAccessible() &&
           Schema.sObjectType.Profile.Fields.PermissionsViewSetup.isAccessible()) {
               if(FeatureManagement.checkPermission('Google_Project_Logout') ||
                  [SELECT PermissionsViewSetup FROM Profile WHERE id =: UserInfo.getProfileId()].PermissionsViewSetup) {
                      access = true;
                  } else {
                      access = false;
                  }
           }
        String token;
        try {
            token = AuthController.CheckTokenAvailability();
            if(token == null) token = AuthController.getAccessToken();
        } catch(Exception e) {
            system.debug(e.getStackTraceString());
        }
        if(token != null) {
            authorized = true;
        }
        
    }
    
    
    public PageReference startAuthorization() {
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
                return new PageReference(GoogleDriveAuthUri(AuthController.googleDrivedKeys.Client_ID__c, redirect_uri));
            }
            when 'onedrive' {
                return new PageReference(OneDriveAuthUri(AuthController.oneDrivedKeys.Client_ID__c, redirect_uri));
            }
        }
        return null;
    }
    
    
    public static PageReference codeCheck() {     //check code after callback from google drive authorization page
        //Get the access token once we have code
        if(code != '' && code != null) {
            AccessToken();
            AuthController.CreateFoldersTree();
            //AuthController.createSetupObjects();
        }
        return new PageReference('/apex/GoogleProject');
    }
    
    
    public static String GoogleDriveAuthUri(String Clientkey, String redirect_uri) {     //create url for google drive authorization page
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
        //system.debug(messageBody);
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
    
    

    public void closeAuthPopup() {      //Log Out popup     
        displayAuthPopup = false;    
    }
    
    public void showAuthPopup() {        
        displayAuthPopup = true;    
    }
    
    public void closeClearPopup() {    //Clear Deleted records popup       
        displayClearPopup = false;    
    }
    
    public void showClearPopup() {        
        displayClearPopup = true;    
    }
    
    
    public PageReference logOutDrive() {     //Log Out from Google Drive
        AuthController.logOutDrive();
        displayAuthPopup = false;
        authorized = false;
        return new PageReference('/apex/GoogleProject');
    }
    

    public void clearDeleted() {  //Clear Deleted records from Drive
        AuthController.clearDeleted();
    }
    
    public void clearArchivedFolder() {     //Clear Archived Folder
        String token = AuthController.CheckTokenAvailability();
        if(token == null) {
            token = AuthController.getAccessToken();
        }

        String mainFolderId = AuthController.getFolderId(AuthController.mainFolderName, null, token);
        String archivedFolderId = AuthController.getFolderId('Archived', mainFolderId, token);
        system.debug(archivedFolderId);
        if(archivedFolderId != null) FoldersListController.DeleteFolder(archivedFolderId, token);
        archivedFolderId = FilesController.CreateSubFolder('Archived', mainFolderId, token, false);
        FilesController.CreateSubFolder('Removed Files', archivedFolderId, token, false);
        FilesController.CreateSubFolder('Removed Records', archivedFolderId, token, false);
        displayClearPopup = false;
    }
}