@isTest 
private class FilesControllerTest {
    @testSetup static void setup() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'gdrive';
        upsert drive;
    }
    
    
    static testMethod void checkAuthorizingTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        Map<String, Object> testMap = (Map<String, Object>) FilesController.checkAuthorizing();

        System.assertEquals(true, (Boolean) testMap.get('access'));
        System.assertEquals(true, (Boolean) testMap.get('auth'));
        Test.stopTest();
    }
    
    
    static testMethod void checkFolderTest() {
        List<Drive_Object__c> dobList = new List<Drive_Object__c>();
        dobList.add(new Drive_Object__c(Name='Account', Label__c='Account', isCreated__c=true));
        dobList.add(new Drive_Object__c(Name='Contact', Label__c='Contact', isCreated__c=false));
        insert dobList;
        
        Test.startTest();
        Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(FilesController.checkFolder('001000000000000'));
        System.assertEquals(true, (Boolean) resp.get('available'));
        
        resp = (Map<String, Object>) JSON.deserializeUntyped(FilesController.checkFolder('003000000000000'));
        System.assertEquals(false, (Boolean) resp.get('available'));
        Test.stopTest();
    }
    
    
    static testMethod void getFilesGDriveTest() {
        Account acc = new Account(Name='test');
        insert acc;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        List<Object> resp = (List<Object>)((Map<String, Object>)FilesController.getFiles(acc.id)).get('fileList');
        
        System.assertEquals(1, resp.size());
        Test.stopTest();
    }
    
    
    static testMethod void getSubfoldersTest() {
        Account acc = new Account(Name='test');
        insert acc;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        List<Object> resp = (List<Object>) JSON.deserializeUntyped(FilesController.getSubfolders(acc.id));
        
        System.assertEquals(1, resp.size());
        Test.stopTest();
    }
    
    
    static testMethod void createRecordFolderTestContactWithoutAccount() {
        Contact con = new Contact(LastName='test');
        insert con;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        String resp = FilesController.createRecordFolder(con.id);
        
        System.assertEquals('{"folderId":"testid","token":"testaccesstoken"}', resp);
        Test.stopTest();
    }
    
    
    static testMethod void createRecordFolderTestContactWithAccount() {
        Account acc = new Account(Name='testAcc');
        insert acc;
        
        Contact con = new Contact(LastName='test', AccountId=acc.id);
        insert con;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        String resp = FilesController.createRecordFolder(con.id);
        
        System.assertEquals('{"folderId":"testid","token":"testaccesstoken"}', resp);
        Test.stopTest();
    }
    
    
    static testMethod void createRecordFolderTestContactWithChild() {
        Contact con = new Contact(LastName='test');
        insert con;
        
        Task tsk = new Task(Subject='TestCall', WhoId=con.id);
        insert tsk;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        String resp = FilesController.createRecordFolder(tsk.id);
        
        System.assertEquals('{"folderId":"testid","token":"testaccesstoken"}', resp);
        Test.stopTest();
    }
    
    
    static testMethod void createRecordFolderTestContactWithAccountAndChild() {
        Account acc = new Account(Name='testAcc');
        insert acc;
        
        Contact con = new Contact(LastName='test', AccountId=acc.id);
        insert con;
        
        Task tsk = new Task(Subject='TestCall', WhoId=con.id);
        insert tsk;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        String resp = FilesController.createRecordFolder(tsk.id);
        
        System.assertEquals('{"folderId":"testid","token":"testaccesstoken"}', resp);
        Test.stopTest();
    }
    
    
    static testMethod void createRecordFolderTestLeadWithoutChild() {
        Lead ld = new Lead(LastName='test', Company='testCompany');
        insert ld;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        String resp = FilesController.createRecordFolder(ld.id);
        
        System.assertEquals('{"folderId":"testid","token":"testaccesstoken"}', resp);
        Test.stopTest();
    }
    
    
    static testMethod void addParentTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        String resp = FilesController.testAddParent();
        
        System.assertEquals('SUCCESS', resp);
        Test.stopTest();
    }
    
    
    static testMethod void removeTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        Boolean resp = FilesController.remove('001000000000000', 'fileId', 'fileName', 'testSub');
        
        System.assertEquals(true, resp);
        Test.stopTest();
    }
    
    
    static testMethod void updateLogGDriveTest() {
        Account acc = new Account(Name='testAcc');
        insert acc;
        
        String testJSON = '[{"name":"testName","type":"testType","size":"testSize"}]';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        String resp = FilesController.updateLog(testJSON, 'action', acc.id, 'abc');
        
        System.assertEquals(true, resp.contains('Log.csv'));
        Test.stopTest();
    }
    
    
    static testMethod void leadConversionTest() {
        Lead testLead = new Lead(
            FirstName='Demo 100800',
            LastName = 'Demo 100800 UnitTest',
            Status='Qualified',
            company='Lacosta',
            street='1211 E I-40 Service Rd',
            city=' Oklahoma City',
            state='OK'
        );
        insert  testLead;
       
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));   
        Database.LeadConvert lc = new database.LeadConvert();
        lc.setLeadId(testLead.Id);
        LeadStatus convertStatus = [Select Id, MasterLabel from LeadStatus where IsConverted=true limit 1];
        lc.setConvertedStatus(convertStatus.MasterLabel);
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        System.assert(lcr.isSuccess());
        
        Test.stopTest();
    }
    
    
    static testMethod void getFileContentTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        String resp = FilesController.getFileContent('logFileId');

        System.assertEquals('test content', resp);
        Test.stopTest();
    }
    
    
    static testMethod void getFilesOneDriveTest() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'onedrive';
        upsert drive;
        
        Account acc = new Account(Name='test');
        insert acc;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        List<Object> resp = (List<Object>)((Map<String, Object>)FilesController.getFiles(acc.id)).get('fileList');
        
        System.assertEquals(1, resp.size());
        Test.stopTest();
    }
    
    
    static testMethod void createRecordFolderTestContactWithAccountOneDrive() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'onedrive';
        upsert drive;
        
        Account acc = new Account(Name='testAcc');
        insert acc;
        
        Contact con = new Contact(LastName='test', AccountId=acc.id);
        insert con;
        
        Task tsk = new Task(Subject='TestCall', WhoId=con.id);
        insert tsk;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(false));
        String resp = FilesController.createRecordFolder(tsk.id);
        
        System.assertEquals('{"folderId":"testid","token":"testaccesstoken"}', resp);
        Test.stopTest();
    }
    
    
    static testMethod void updateLogOneDriveTest() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'onedrive';
        upsert drive;
        
        Account acc = new Account(Name='testAcc');
        insert acc;
        
        String testJSON = '[{"name":"testName","type":"testType","size":"testSize"}]';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        String resp = FilesController.updateLog(testJSON, 'action', acc.id, 'abc');
        
        System.assertEquals(true, resp.contains('testName'));
        Test.stopTest();
    }
}