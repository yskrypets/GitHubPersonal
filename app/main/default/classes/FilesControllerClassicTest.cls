@isTest 
private class FilesControllerClassicTest {
    static FilesControllerClassic fcc = new FilesControllerClassic();
    
    @testSetup static void setup() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'gdrive';
        upsert drive;
        fcc.driveName = 'gdrive';
    }
    
    static testMethod void RecordIdGDriveTest() {
        Account acc = new Account(Name='testAcc');
        insert acc;
        
        List<Drive_Object__c> dobList = new List<Drive_Object__c>();
        dobList.add(new Drive_Object__c(Name='Account', Label__c='Account', isCreated__c=true));
        insert dobList;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        System.assertEquals(null, fcc.files);
        fcc.recordId = acc.id;
        fcc.reloadFiles();
        System.assertEquals(acc.id, fcc.recordId);
        
        Test.stopTest();
    }
    
    static testMethod void RecordIdOneDriveTest() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'onedrive';
        upsert drive;
        
        Account acc = new Account(Name='testAcc');
        insert acc;
        
        List<Drive_Object__c> dobList = new List<Drive_Object__c>();
        dobList.add(new Drive_Object__c(Name='Account', Label__c='Account', isCreated__c=true, Parent_Object__c='Account'));
        insert dobList;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        System.assertEquals(null, fcc.files);
        fcc.recordId = acc.id;
        fcc.reloadFiles();
        System.assertEquals(acc.id, fcc.recordId);
        
        Test.stopTest();
    }
    
    static testMethod void getFolderIdTest() {
        Account acc = new Account(Name='testAcc');
        insert acc;
        
        Contact con = new Contact(LastName='test', AccountId=acc.id);
        insert con;
        
        Task tsk = new Task(Subject='TestCall', WhoId=con.id);
        insert tsk;
        
        List<Drive_Object__c> dobList = new List<Drive_Object__c>();
        dobList.add(new Drive_Object__c(Name='Account', Label__c='Account', isCreated__c=true));
        insert dobList;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        
        fcc.recordId = tsk.id;
        String folderId = fcc.getFolderId(tsk.id, 'parentIdTest', 'contains', true);
        
        System.assertEquals('testid', folderId);
        
        Test.stopTest();
    }
    
    
    static testMethod void createRecordFolderTest() {
        Contact con = new Contact(LastName='test');
        insert con;
        
        Drive_Object__c dob = new Drive_Object__c(Name='Contact', Label__c='Contact', isCreated__c=true);
        insert dob;
        
        Subfolder__c sf = new Subfolder__c(Name='test', Drive_Object__c=dob.id);
        insert sf;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        String resp = JSON.serialize(FilesControllerClassic.createRecordFolder(con.id));
        
        System.assertEquals('{"token":"testaccesstoken","folderId":"testid","test":"testid"}', resp);
        Test.stopTest();
    }
    
    
    static testMethod void getSubfoldersTest() {
        Account acc = new Account(Name='test');
        insert acc;
        
        fcc.recordId = acc.id;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        List<SelectOption> resp = fcc.getSubfolders();
        
        System.assertEquals(1, resp.size());
        Test.stopTest();
    }
    
    
    static testMethod void removeTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        Boolean resp = FilesControllerClassic.remove('001000000000000', 'fileId', 'fileName');
        System.assertEquals(true, resp);
        
        resp = FilesControllerClassic.removeFile('001000000000000', 'fileId', 'fileName', null);
        System.assertEquals(true, resp);
        Test.stopTest();
    }
    
    
    static testMethod void updateLogTest() {
        Account acc = new Account(Name='testAcc');
        insert acc;
        
        String testJSON = '[{"name":"testName","type":"testType","size":"testSize"}]';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        String resp = FilesControllerClassic.updateLog(testJSON, 'action', acc.id, 'abc');
        
        System.assertEquals(true, resp.contains('Log.csv'));
        Test.stopTest();
    }
}