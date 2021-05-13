@isTest 
private class FilesActionsTest {
    @testSetup static void setup() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.Files_Action__c = 'copy';
        drive.External_Drive_Name__c = 'gdrive';
        upsert drive;
        
        Drive_Object__c dob = new Drive_Object__c(Name='Account', Label__c='Account', isCreated__c=true);
        insert dob;
        
        Account acct = new Account(Name='TEST_ACCT');
        insert acct;
        
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Test',
            PathOnClient = 'Test.txt',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert contentVersion;
        List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];
        
        ContentDocumentLink cdl = New ContentDocumentLink();
        cdl.LinkedEntityId = acct.id;
        cdl.ContentDocumentId = documents[0].Id;
        cdl.shareType = 'V';
        insert cdl;     
    }
    
    
    static testMethod void copyBatchGDriveTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        DataBase.executeBatch(new FilesActionsBatch('copy', 'token'));
        
        System.assertEquals(1, [SELECT id FROM ContentDocument].size());
        Test.stopTest();
    }
    
    
    static testMethod void copyBatchOneDriveTest() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'onedrive';
        upsert drive;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        DataBase.executeBatch(new FilesActionsBatch('copy', 'token'));
        
        System.assertEquals(1, [SELECT id FROM ContentDocument].size());
        Test.stopTest();
    }
    
    
    static testMethod void moveBatchTest() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.Files_Action__c = 'move';
        upsert drive;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        DataBase.executeBatch(new FilesActionsBatch('move', 'token'));
        
        System.assertEquals(1, [SELECT id FROM ContentDocument].size());
        Test.stopTest();
    }
}