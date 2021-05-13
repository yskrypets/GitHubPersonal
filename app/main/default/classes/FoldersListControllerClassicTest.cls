@isTest 
private class FoldersListControllerClassicTest {
    static FoldersListControllerClassic flcc = new FoldersListControllerClassic();
    @testSetup static void setup() {
        Drive__c drive = Drive__c.getOrgDefaults();
        drive.External_Drive_Name__c = 'gdrive';
        upsert drive;
    }
    
    
    static testMethod void checkAllTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        flcc.isCheck = false;
        flcc.checkObject(); 
        flcc.checkAll();
        Boolean allChecked = true;
        for(FoldersListControllerClassic.Folders fld : flcc.folders) {
            if(!fld.Checked) allChecked = false;
            if(fld.hasChilds) {
                for(FoldersListControllerClassic.Folders cld : fld.Childs) {
                    if(!cld.Checked) allChecked = false;
                    if(cld.hasChilds) {
                        for(FoldersListControllerClassic.Folders subCld : cld.Childs) {
                            if(!subCld.Checked) allChecked = false;
                        }
                    }
                }
            }
        }
        
        System.assertEquals(false, allChecked);
        Test.stopTest();
    }
    
    
    static testMethod void unCheckAllTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        flcc.isCheck = true;
        flcc.checkObject(); 
        flcc.checkAll();
        Boolean allChecked = true;
        for(FoldersListControllerClassic.Folders fld : flcc.folders) {
            if(!fld.Checked) allChecked = false;
            if(fld.hasChilds) {
                for(FoldersListControllerClassic.Folders cld : fld.Childs) {
                    if(!cld.Checked) allChecked = false;
                    if(cld.hasChilds) {
                        for(FoldersListControllerClassic.Folders subCld : cld.Childs) {
                            if(!subCld.Checked) allChecked = false;
                        }
                    }
                }
            }
        }
        
        System.assertEquals(false, allChecked);
        Test.stopTest();
    }
    
    
    static testMethod void checkAllObjsTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        Boolean allChecked = false;
        flcc.checkObj();
        flcc.checkAllObjs();
        for(FoldersListControllerClassic.Objects obj : flcc.objects) {
            if(obj.Checked) allChecked = true;
        }
        System.assertEquals(false, allChecked);
        Test.stopTest();
    }
    
    
    static testMethod void closeChildTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        
        for(FoldersListControllerClassic.Folders fld : flcc.folders) {
            if(fld.Name == 'Account') fld.Opened = true;
        }
        
        flcc.fldLvlCount = 2;
        flcc.fldNameMap = new Map<String, String>{'one'=>'Account','two'=>'Opportunity','three'=>'','four'=>'','five'=>'','six'=>''};
        flcc.closeChild();
        
        for(FoldersListControllerClassic.Folders fld : flcc.folders) {
            if(fld.Name == 'Opportunity') System.assertEquals(false, fld.Opened);
        }
        
        Test.stopTest();
    }
    
    static testMethod void openChildTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        
        for(FoldersListControllerClassic.Folders fld : flcc.folders) {
            if(fld.Name == 'Opportunity') fld.Opened = false;
        }
        
        flcc.fldLvlCount = 2;
        flcc.fldNameMap = new Map<String, String>{'one'=>'Account','two'=>'Opportunity','three'=>'','four'=>'','five'=>'','six'=>''};
        flcc.openChild();
        
        for(FoldersListControllerClassic.Folders fld : flcc.folders) {
            if(fld.Name == 'Opportunity') System.assertEquals(true, fld.Opened);
        }
        
        Test.stopTest();
    }
    
    static testMethod void openSubChildTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        
        for(FoldersListControllerClassic.Folders fld : flcc.folders) {
            if(fld.Name == 'Account') {
                for(FoldersListControllerClassic.Folders cld : fld.Childs) {
                    if(cld.Name == 'Contact') fld.Opened = false;
                }
            }
        }
        
        for(FoldersListControllerClassic.Folders fld : flcc.folders) {
            if(fld.Name == 'Account') {
                for(FoldersListControllerClassic.Folders cld : fld.Childs) {
                    if(cld.Name == 'Contact') System.assertEquals(true, cld.Opened);
                }
            }
        }
        
        Test.stopTest();
    }
    
    static testMethod void closeUpdPopupTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        flcc.displayUpdPopUp = true;
        flcc.updateFolders();
        flcc.closeUpdPopup();
        
        System.assertEquals(false, flcc.displayUpdPopUp);
        Test.stopTest();
    }
    
    static testMethod void showUpdPopupTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        flcc.displayUpdPopUp = false;
        flcc.showUpdPopup();
        
        System.assertEquals(true, flcc.displayUpdPopUp);
        Test.stopTest();
    }
    
    static testMethod void getActionsTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        List<SelectOption> act = flcc.getActions();
        
        System.assertEquals(3, act.size());
        Test.stopTest();
    }
    
    static testMethod void onChangeTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        flcc.selectedAction = 'nothing';
        flcc.onChange();
        
        System.assertEquals('nothing', Drive__c.getInstance().Files_Action__c);
        Test.stopTest();
    }
    
    static testMethod void applyTest() {
        flcc.initialization = 'true';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFakeResponse());
        flcc.selectedAction = 'copy';
        flcc.objects[0].Checked = true;
        flcc.generatePages();
        flcc.apply();
        
        System.assertEquals('copy', Drive__c.getInstance().Files_Action__c);
        Test.stopTest();
    }
    
    static testMethod void rowIncTest() {
        flcc.initialization = 'true';
        
        Drive_Object__c dob = new Drive_Object__c(Name='test1', Label__c='test1', isCreated__c=false);
        insert dob;
        
        Subfolder__c sf = new Subfolder__c(Name='testSub1', Drive_Object__c=dob.id);
        insert sf;
        
        flcc.fillSubfolders();
        flcc.fldTempName = 'test1';
        flcc.newSubfolderName = 'testSub2';
        flcc.rowInc();
        system.assertEquals(1, flcc.subfolders.size());
    }
    
    static testMethod void rowDecTest() {
        flcc.initialization = 'true';
        
        Drive_Object__c dob = new Drive_Object__c(Name='test1', Label__c='test1', isCreated__c=false);
        insert dob;
        
        Subfolder__c sf = new Subfolder__c(Name='testSub1', Drive_Object__c=dob.id);
        insert sf;
        
        flcc.fillSubfolders();
        flcc.fldTempName = 'test1';
        flcc.cldTempName = 'testSub1';
        flcc.rowDec();
        system.assertEquals(1, flcc.subfolders.size());
    }
}