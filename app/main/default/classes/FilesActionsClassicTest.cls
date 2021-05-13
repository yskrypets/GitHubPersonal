@isTest 
private class FilesActionsClassicTest {
    @testSetup static void setup() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.Files_Action__c = 'copy';
        drive.External_Drive_Name__c = 'gdrive';
        upsert drive;
        
        Drive_Object__c dob = new Drive_Object__c(Name='Account', Label__c='Account', isCreated__c=true);
        insert dob;
        
        Account acct = new Account(Name='TEST_ACCT');
        insert acct;
        
        Attachment att = New Attachment();
        att.Name = 'Test.txt';
        att.ParentId = acct.id;
        att.Body = Blob.valueOf('Test Content');
        insert att;      
    }
    
    
    static testMethod void copyBatchGDriveTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        DataBase.executeBatch(new FilesActionsClassicBatch('copy', 'token'));
        
        System.assertEquals(1, [SELECT id FROM Attachment].size());
        Test.stopTest();
    }
    
    
    static testMethod void copyBatchOneDriveTest() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'onedrive';
        upsert drive;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        DataBase.executeBatch(new FilesActionsClassicBatch('copy', 'token'));
        
        System.assertEquals(1, [SELECT id FROM Attachment].size());
        Test.stopTest();
    }
    
    
    static testMethod void moveBatchTest() {
		Drive__c drive = Drive__c.getOrgDefaults();
        drive.Files_Action__c = 'move';
        upsert drive;        

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        DataBase.executeBatch(new FilesActionsClassicBatch('move', 'token'));
        
        System.assertEquals(1, [SELECT id FROM Attachment].size());
        Test.stopTest();
    }
}