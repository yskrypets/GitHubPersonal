@isTest 
private class AuthControllerClassicTest {
    static AuthControllerClassic acc = new AuthControllerClassic();
    
    @testSetup static void setup() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'gdrive';
        upsert drive;       
    }
    
    static testMethod void driveAuthUriGDriveTest() {
        acc.externalDriveName = 'gdrive';
        PageReference authUri = acc.startAuthorization();
        System.assertEquals('https://accounts.google.com/o/oauth2/auth', authUri.getUrl().substring(0, authUri.getUrl().indexOf('?')));
    }
    
    static testMethod void driveAuthUriOneDriveTest() {
        acc.externalDriveName = 'onedrive';
        PageReference authUri = acc.startAuthorization();
        System.assertEquals('https://login.microsoftonline.com/common/oauth2/v2.0/authorize', authUri.getUrl().substring(0, authUri.getUrl().indexOf('?')));
    }
    
    static testMethod void codeCheckTest() {
        Test.setCurrentPageReference(new PageReference(AuthControllerClassic.redirect_uri)); 
        System.currentPageReference().getParameters().put('code', 'testcode');
        System.currentPageReference().getParameters().put('state', AuthControllerClassic.redirect_uri);
        AuthControllerClassic.code = 'testcode';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        PageReference testPage = AuthControllerClassic.codeCheck();
        
        System.assertEquals('/apex/GoogleProject', testPage.getUrl());
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
        
        PageReference testPage = acc.logOutDrive();
        
        System.assertEquals('/apex/GoogleProject', testPage.getUrl());
        System.assertEquals(null, Drive__c.getOrgDefaults().AccessToken1__c);
        System.assertEquals(null, Drive__c.getOrgDefaults().RefreshToken1__c);
        Test.stopTest();
    }
    
    
    static testMethod void clearDeletedTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        acc.clearDeleted();
        acc.closeAuthPopup();
        System.assertEquals(false, acc.displayAuthPopup);
        
        acc.showAuthPopup();
        System.assertEquals(true, acc.displayAuthPopup);
        Test.stopTest();
    }
    
    
    static testMethod void clearArchivedFolderTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        
        acc.closeClearPopup();
        acc.clearArchivedFolder();
        System.assertEquals(false, acc.displayClearPopup);
        
        acc.showClearPopup();
        System.assertEquals(true, acc.displayClearPopup);
        Test.stopTest();
    }
}