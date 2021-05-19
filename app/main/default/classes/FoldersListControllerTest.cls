@isTest 
private class FoldersListControllerTest {
    @testSetup static void setup() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'gdrive';
        upsert drive;
    }
    
    
    static testMethod void checkAuthorizingTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        Map<String, Object> testMap = (Map<String, Object>) FoldersListController.checkAuthorizing();

        System.assertEquals(true, (Boolean) testMap.get('access'));
        System.assertEquals(true, (Boolean) testMap.get('auth'));
        Test.stopTest();
    }
    
    
    static testMethod void checkFilesActionTest() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.Files_Action__c = 'copy';
        upsert drive;
        
        Test.startTest();
        String action = FoldersListController.checkFilesAction();
        
        System.assertEquals('copy', action);
        
        drive.Files_Action__c = '';
        upsert drive;
        
        action = FoldersListController.checkFilesAction();
        
        System.assertEquals('nothing', action);
        Test.stopTest();
    }
    
    
    static testMethod void actionWithFilesTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        String resp = FoldersListController.actionWithFiles('nothing');
        
        System.assertEquals('SUCCESS', resp);
        System.assertEquals('nothing', Drive__c.getOrgDefaults().Files_Action__c);
        Test.stopTest();
    }
    
    
    static testMethod void saveActionWithFilesTest() {
        Test.startTest();
        String resp = FoldersListController.saveActionWithFiles('nothing');
        
        System.assertEquals('SUCCESS', resp);
        System.assertEquals('nothing', Drive__c.getOrgDefaults().Files_Action__c);
        Test.stopTest();
    }
    
    
    static testMethod void getFoldersTest() {
        Map<String, Schema.SObjectType> forSeparate = AuthController.whiteList;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        List<Object> resp = FoldersListController.getFolders();
        
        System.assertEquals(true, forSeparate.size() >= resp.size());
        Test.stopTest();
    }
    
    
    static testMethod void fillSubfoldersTest() {
        Drive_Object__c dob = new Drive_Object__c(Name='test1', Label__c='test1', isCreated__c=false);
        insert dob;
        
        Subfolder__c sf = new Subfolder__c(Name='test', Drive_Object__c=dob.id);
        insert sf;
        
        Test.startTest();
        List<Object> resp = (List<Object>) JSON.deserializeUntyped(FoldersListController.fillSubfolders());
        
        System.assertEquals(1, resp.size());
        Test.stopTest();
    }
    
    
    static testMethod void addSubfolderCtrlTest() {
        Drive_Object__c dob = new Drive_Object__c(Name='test1', Label__c='test1', isCreated__c=false);
        insert dob;
        
        Test.startTest();
        List<Object> resp = (List<Object>) JSON.deserializeUntyped(FoldersListController.addSubfolderCtrl('test1', 'testSub'));
        
        System.assertEquals(1, resp.size());
        Test.stopTest();
    }
    
    
    static testMethod void removeSubfolderCtrlTest() {
        Drive_Object__c dob = new Drive_Object__c(Name='test1', Label__c='test1', isCreated__c=false);
        insert dob;
        
        Subfolder__c sf = new Subfolder__c(Name='testSub', Drive_Object__c=dob.id);
        insert sf;
        
        Test.startTest();
        List<Object> resp = (List<Object>) JSON.deserializeUntyped(FoldersListController.removeSubfolderCtrl('test1', 'testSub'));
        
        System.assertEquals(1, resp.size());
        Test.stopTest();
    }
    
    
    static testMethod void updDriveFoldersTest() {
        String fakeJSON = '[{"Name":"test1","Label":"test1","Checked":true,"hasChilds":true,"Childs":[{"Name":"test2","Label":"test2","Checked":true,"hasChilds":true,"Childs":[{"Name":"test3","Label":"test3","Checked":true,"hasChilds":false,"Childs":[]}]}]},';
        fakeJSON += '{"Name":"test4","Label":"test4","Checked":true,"hasChilds":true,"Childs":[{"Name":"test5","Label":"test5","Checked":true,"hasChilds":true,"Childs":[{"Name":"test6","Label":"test6","Checked":true,"hasChilds":false,"Childs":[]}]}]}]';
        List<Drive_Object__c> doList = new List<Drive_Object__c>();
        doList.add(new Drive_Object__c(Name='test1', Label__c='test1', isCreated__c=false));
        doList.add(new Drive_Object__c(Name='test2', Label__c='test2', isCreated__c=false));
        doList.add(new Drive_Object__c(Name='test3', Label__c='test3', isCreated__c=false));
        insert doList;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());

        FoldersListController.moveFolder('folderId', 'targeParentId', 'oldParentId', 'token');
        FoldersListController.DeleteFolder('folderId', 'token');
        List<Object> resp = FoldersListController.updDriveFolders(fakeJSON);
        
        System.assertEquals(2, resp.size());
        System.assertEquals(6, [SELECT count() FROM Drive_Object__c]);
        Test.stopTest();
    }
    
    
    static testMethod void getFolderIdTest() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse(true));
        String resp = FoldersListController.getFolderId('folderName', 'parentId');
        
        System.assertEquals('testid', resp);
        Test.stopTest();
    }
}