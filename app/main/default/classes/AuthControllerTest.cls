@isTest 
private class AuthControllerTest {
    @testSetup static void setup() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'gdrive';
        upsert drive;       
    }
    
    
    static testMethod void driveAuthUriGDriveTest() {
        String authUri = AuthController.authDrive('gdrive');
        System.assertEquals('https://accounts.google.com/o/oauth2/auth', authUri.substring(0, authUri.indexOf('?')));
    }
    
    
    static testMethod void driveAuthUriOneDriveTest() {
        String authUri = AuthController.authDrive('onedrive');
        System.assertEquals('https://login.microsoftonline.com/common/oauth2/v2.0/authorize', authUri.substring(0, authUri.indexOf('?')));
    }
    
    
    static testMethod void codeCheckTest() {
        Test.setCurrentPageReference(new PageReference(AuthController.redirect_uri)); 
        System.currentPageReference().getParameters().put('code', 'testcode');
        System.currentPageReference().getParameters().put('state', AuthController.redirect_uri);
        AuthController.code = 'testcode';
        insert new Drive_Object__c(Name='Account', isCreated__c=true);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        PageReference testPage = AuthController.codeCheck();
        
        System.assertEquals('/one/one.app?source=alohaHeader#/n/Google_Project', testPage.getUrl());
        Test.stopTest();
    }
    
    
    static testMethod void checkAuthorizingTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        Map<String, Object> testMap = (Map<String, Object>) AuthController.checkAuthorizing();

        System.assertEquals(true, (Boolean) testMap.get('access'));
        System.assertEquals(true, (Boolean) testMap.get('auth'));
        Test.stopTest();
    }
    
    
    static testMethod void checkAuthorizingWithoutSaveTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        Map<String, Object> testMap = (Map<String, Object>) AuthController.checkAuthorizingWithoutSave();

        System.assertEquals(true, (Boolean) testMap.get('access'));
        System.assertEquals(true, (Boolean) testMap.get('auth'));
        Test.stopTest();
    }
    
    
    static testMethod void logOutDriveTest() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.AccessToken1__c = '111';
        drive.RefreshToken1__c = '222';
        upsert drive;
        
        Test.startTest();
        System.assertEquals('111', Drive__c.getOrgDefaults().AccessToken1__c);
        System.assertEquals('222', Drive__c.getOrgDefaults().RefreshToken1__c);
        
        AuthController.logOutDrive();
        
        System.assertEquals(null, Drive__c.getOrgDefaults().AccessToken1__c);
        System.assertEquals(null, Drive__c.getOrgDefaults().RefreshToken1__c);
        Test.stopTest();
    }
    
    
    static testMethod void clearDeletedGDriveTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        String resp = AuthController.clearDeleted();
        System.assertEquals('SUCCESS', resp);
        Test.stopTest();
    }
    
    
    static testMethod void clearDeletedOneDriveTest() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'onedrive';
        upsert drive; 
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        String resp = AuthController.clearDeleted();
        System.assertEquals('SUCCESS', resp);
        Test.stopTest();
    }
    
    
    static testMethod void clearArchivedFolderTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        String resp = AuthController.clearArchivedFolder();
        System.assertEquals('SUCCESS', resp);
        Test.stopTest();
    }
}