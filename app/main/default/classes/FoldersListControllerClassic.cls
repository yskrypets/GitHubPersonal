public with sharing class FoldersListControllerClassic {
    public List<Drive_Object__c> drvObjList {get;set;}
    public String token {get;set;}
    public Boolean selectAll {get;set;}
    public Boolean selectAllObjs {get;set;}
    public List<Folders> folders {get;set;}
    public List<Objects> objects {get;set;}
    public List<Folders> subfolders {get;set;}
    public String generatedAlertString {get;set;}
    public Boolean displayUpdPopUp {get;set;}
    public Boolean authorized {get;set;}
    public String fldTempName {get;set;}
    public String cldTempName {get;set;}
    public String newSubfolderName {get;set;}
    
    public FoldersListControllerClassic() {
        
    }
    
    
    private Boolean init = false;
    public String initialization {
        get;set{
            if(!init) {
                initMethod();
                init = true;
            }
        }
    }
    
    
    private void initMethod() {
        drvObjList = new List<Drive_Object__c>();
        fldNameMap = new Map<String, String>{'one'=>'','two'=>'','three'=>'','four'=>'','five'=>'','six'=>''};
        selectAll = true;
        selectAllObjs = false;
        folders = new List<Folders>();
        objects = getObjectsList();
        if(objects == null || objects.isEmpty()) {
            objects = null;
        } else {
            objects.sort();
        }
        List<Map<String, Object>> objList = FoldersListController.getObjectsList();
        folders = fillFoldersList(objList, null);
        fillSubfolders();
        checkAuthorizing();
        selectedAction = FoldersListController.checkFilesAction();
    }
    
    
    public class Folders implements Comparable {
        public Boolean Checked {get;set;}
        public Boolean hasChilds {get;set;}
        public Boolean Opened {get;set;}
        public String Name {get;set;}
        public String Label {get;set;}
        public String Parent {get;set;}
        public Integer row {get;set;}
        public List<Folders> Childs {get;set;}
        
        public Folders() {
            row = 0;
        }
        
        public Integer compareTo(Object compareTo) {
            Folders fld = (Folders) compareTo;
            if(Label == fld.Label) return 0;
            if(Label > fld.Label) return 1;
            return -1;
        }
    }
    
    
    public class Objects implements Comparable {
        public Boolean Checked {get;set;}
        public String Name {get;set;}
        public String Label {get;set;}
        
        public Integer compareTo(Object compareTo) {
            Objects obj = (Objects) compareTo;
            if (Name == obj.Name) {
                return 0;
            }
            if (Name > obj.Name) {
                return 1;
            }
            return -1;
        }
    }
    
    
    public void rowInc() {
        for(Folders fld : subfolders) {
            if(fld.Name.equalsIgnoreCase(fldTempName)) {
                if(fld.Childs == null) fld.Childs = new List<Folders>();
                Folders subfld = new Folders();
                subfld.Name = newSubfolderName;
                fld.Childs.add(subfld);
                fld.row++;
                break;
            }
        }
        List<Subfolder__c> newSubs = new List<Subfolder__c>();
        if(Schema.sObjectType.Subfolder__c.isCreateable() &&
          Schema.sObjectType.Subfolder__c.Fields.Drive_Object__c.isCreateable() && 
          Schema.sObjectType.Subfolder__c.Fields.Name.isCreateable()) {
            for(Drive_Object__c drvObj : drvObjList) {
                if(drvObj.Name.equalsIgnoreCase(fldTempName)) {
                    newSubs.add(new Subfolder__c(Drive_Object__c=drvObj.id, Name=newSubfolderName));
                    break;
                }
            }
            if(!newSubs.isEmpty()) insert newSubs;
        }
        fldTempName = null;
        newSubfolderName = null;
        fillSubfolders();
    }
    
    
    public void rowDec() {
        for(Folders fld : subfolders) {
            if(fld.Name.equalsIgnoreCase(fldTempName)) {
                for(Integer i = 0; i <= fld.Childs.size(); i++) {
                    if(fld.Childs[i].Name.equalsIgnoreCase(cldTempName)) {
                        fld.Childs.remove(i);
                        fld.row--;
                        break;
                    }
                }
                break;
            }
        }
        List<Subfolder__c> subForRemove = new List<Subfolder__c>();
        for(Drive_Object__c drvObj : drvObjList) {
            if(drvObj.Name.equalsIgnoreCase(fldTempName) && !drvObj.Subfolders__r.isEmpty()) {
                for(Subfolder__c sub : drvObj.Subfolders__r) {
                    if(sub.Name.equalsIgnoreCase(cldTempName)) {
                        subForRemove.add(sub);
                        break;
                    }
                }
                break;
            }
        }
        if(!subForRemove.isEmpty() && Schema.sObjectType.Subfolder__c.isDeletable()) delete subForRemove;
        fldTempName = null;
        cldTempName = null;
        fillSubfolders();
    }
    
    
    public void fillSubfolders() {
        if(Schema.sObjectType.Drive_Object__c.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Name.isAccessible() && Schema.sObjectType.Drive_Object__c.Fields.Label__c.isAccessible() 
          && Schema.sObjectType.Subfolder__c.isAccessible() && Schema.sObjectType.Subfolder__c.Fields.Name.isAccessible()) {
                drvObjList = [SELECT id, Name, Label__c, (SELECT id, Name FROM Subfolders__r LIMIT 50000) FROM Drive_Object__c LIMIT 50000];
          }
        subfolders = new List<Folders>();
        for(Drive_Object__c obj : drvObjList) {
            Folders fld = new Folders();
            fld.Name = obj.Name;
            fld.Label = obj.Label__c;
            if(!obj.Subfolders__r.isEmpty()) {
                fld.Childs = new List<Folders>();
                for(Subfolder__c sub : obj.Subfolders__r) {
                    Folders cld = new Folders();
                    cld.Name = sub.Name;
                    fld.Childs.add(cld);
                }
            }
            subfolders.add(fld);
        }
        subfolders.sort();
    }
    
    
    private List<Objects> getObjectsList() {
        Set<String> alreadyCreated = new Set<String>();
        if(Schema.sObjectType.ApexPage.isAccessible() &&
           Schema.sObjectType.ApexPage.Fields.Name.isAccessible()) {
               List<ApexPage> pagesList = [SELECT id, Name FROM ApexPage WHERE Name like 'FilePane_%'];
               for(ApexPage ap : pagesList) {
                   alreadyCreated.add(ap.Name.substringAfter('FilePane_'));
               }
           }
        
        Map<String, Schema.SObjectType> allobj = AuthController.whiteList;
        List<Objects> objList = new List<Objects>();

        for(String objName : allobj.keySet()) {
            Schema.DescribeSObjectResult dor = allobj.get(objName).getDescribe();
            if(!alreadyCreated.contains(dor.getName().replace('baobab_drive__', '').remove('__c')) && dor.isQueryable() && dor.isDeletable() && dor.isCreateable() && dor.isAccessible()) {
                Objects obj = new Objects();
                obj.Name = dor.getName();
                obj.Label = dor.getLabel();
                obj.Checked = false;
                objList.add(obj);
            }
        }
        return objList;
    }
    
    
    private void checkAuthorizing() {
        authorized = false;
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
    
    
    public Boolean multiParent {get;set;}
    
    public void closeMultiParent() {
        multiParent = false;
    }
    
    
    //Working with checkboxes
    public void checkAll() {
        multiParent = false;
        Set<String> checked = new Set<String>();
        checkAllHelper(folders, checked);
    }
    
    public void checkAllHelper(List<Folders> flds, Set<String> checked) {
        if(flds != null) {
            for(Folders fld : flds) {
                if(selectAll) {
                    if(checked.contains(fld.Name)) {
                        multiParent = true;
                        fld.Checked = false;
                    } else {
                        fld.Checked = true;
                        checked.add(fld.Name);
                    }
                } else {
                    fld.Checked = false;
                }
                if(fld.hasChilds) {
                    checkAllHelper(fld.Childs, checked);
                }
            }
        }
    }
    
    public Boolean allChecked;
    public Boolean isCheck {get;set;}
    public String isChanged {get;set;}
    
    public void checkObject() {
        system.debug(isChanged + ' - ' + isCheck);
        isCheck = !isCheck;
        allChecked = true;
        if(isCheck) {
            uncheckSame(folders, false);
            trueCheckObjectHelper(folders);
        } else {
            falseCheckObjectHelper(folders, true);
        }
        checkIfAllCheckedHelper(folders);
        selectAll = allChecked;
        fldLvlCount = 1;
        isChanged = null;
    }
    
    public void checkIfAllCheckedHelper(List<Folders> flds) {
        if(flds != null) {
            for(Folders fld : flds) {
                if(!fld.Checked) {
                    allChecked = false;
                }
                if(fld.hasChilds) {
                    checkIfAllCheckedHelper(fld.Childs);
                }
            }
        }
    }
    
    public Boolean trueCheckObjectHelper(List<Folders> flds) {
        if(flds != null) {
            for(Folders fld : flds) {
                if(fld.Name.equalsIgnoreCase(fldNameMap.get(tempParse.get(fldLvlCount)))) {
                    if(fldNameMap.get(tempParse.get(fldLvlCount+1)) != '') {
                        fldLvlCount++;
                        fld.Checked = trueCheckObjectHelper(fld.Childs);
                    }
                    if(isChanged.equalsIgnoreCase(fld.Name)) fld.Checked = true;
                    return true;
                }
            }
        }
        return false;
    }
    
    
    public void falseCheckObjectHelper(List<Folders> flds, Boolean isChecked) {
        if(flds != null) {
            for(Folders fld : flds) {
                if(!isChecked) {
                    fld.Checked = false;
                    allChecked = false;
                    if(fld.hasChilds) {
                        falseCheckObjectHelper(fld.Childs, false);
                    }
                } else {
                    if(fld.Checked) {
                        if(fld.hasChilds) {
                            falseCheckObjectHelper(fld.Childs, true);
                        }
                    } else {
                        allChecked = false;
                        if(fld.hasChilds) {
                            falseCheckObjectHelper(fld.Childs, false);
                        }
                    }
                }
            }
        }
    }
    
    
    
    public void checkAllObjs() {
        for(Objects obj : objects) {
            obj.Checked = selectAllObjs;
        }
    }
    
    public void checkObj() {
        Boolean allChecked = true;
        for(Objects obj : objects) {
            if(obj.Checked == false) allChecked = false;
        }
        if(allChecked) {
            selectAllObjs = true;
        } else {
            selectAllObjs = false;
        }
    }
    
    
    public void uncheckSame(List<Folders> flds, Boolean shouldUncheck) {
        if(flds != null) {
            for(Folders fld : flds) {
                if(fld.Name.equalsIgnoreCase(isChanged) || shouldUncheck) {
                    fld.Checked = false;
                }
                if(fld.hasChilds) {
                    uncheckSame(fld.Childs, fld.Name.equalsIgnoreCase(isChanged) ? true : false);
                }
            }
        }
    }
    
    
    //Show/Hide childs/sub-childs
    public Map<String, String> fldNameMap {get; set;}
    private Map<Integer, String> tempParse {get{return new Map<Integer, String>{1=>'one',2=>'two',3=>'three',4=>'four',5=>'five',6=>'six'};}}
    public Integer fldLvlCount = 1;
    
    public void closeChild() {
        closeChildHelper(folders);
        fldNameMap = new Map<String, String>{'one'=>'','two'=>'','three'=>'','four'=>'','five'=>'','six'=>''};
        fldLvlCount = 1;
    }
    
    public void openChild() {
        openChildHelper(folders);
        fldNameMap = new Map<String, String>{'one'=>'','two'=>'','three'=>'','four'=>'','five'=>'','six'=>''};
        fldLvlCount = 1;
    }
    
    public void closeChildHelper(List<Folders> flds) {
        if(flds != null) {
            for(Folders fld : flds) {
                if(fld.Name.equalsIgnoreCase(fldNameMap.get(tempParse.get(fldLvlCount)))) {
                    if(fldNameMap.get(tempParse.get(fldLvlCount+1)) != '') {
                        fldLvlCount++;
                        closeChildHelper(fld.Childs);
                    } else {
                        fld.Opened = false;
                    }
                }
            }
        }
    }
    
    public void openChildHelper(List<Folders> flds) {
        if(flds != null) {
            for(Folders fld : flds) {
                if(fld.Name.equalsIgnoreCase(fldNameMap.get(tempParse.get(fldLvlCount)))) {
                    if(fldNameMap.get(tempParse.get(fldLvlCount+1)) != '') {
                        fldLvlCount++;
                        openChildHelper(fld.Childs);
                    } else {
                        fld.Opened = true;
                    }
                }
            }
        }
    }
    
    
    
    
    //Update popup
    public void closeUpdPopup() {        
        displayUpdPopUp = false;    
    }
    
    public void showUpdPopup() {        
        displayUpdPopUp = true;    
    }
    
    public void updateFolders() {
        displayUpdPopUp = false;
        FoldersListController.updDriveFolders(JSON.serialize(folders));
    }
    
    
    public List<Folders> fillFoldersList(List<Object> objList, String parentName) {
        List<Folders> fldList = new List<Folders>();
        for(Object obj : objList) {
            Map<String, Object> objMap = (Map<String, Object>) obj;
            if(!(Boolean) objMap.get('Checked')) selectAll = false;
            Folders fld = new Folders();
            fld.Checked = (parentName != null && parentName.equalsIgnoreCase((String) objMap.get('Parent'))) || parentName == null ? (Boolean) objMap.get('Checked') : false;
            fld.hasChilds = (Boolean) objMap.get('hasChilds');
            fld.Opened = (Boolean) objMap.get('Opened');
            fld.Name = (String) objMap.get('Name');
            fld.Label = (String) objMap.get('Label');
            fld.Parent = parentName;
            //system.debug((String) objMap.get('Label') + ' - ' + (Boolean) objMap.get('Checked') + ' - ' + (String) objMap.get('Parent') + ' - ' + parentName);
            if((Boolean) objMap.get('hasChilds')) {
                fld.Childs = fillFoldersList((List<Map<String, Object>>) objMap.get('Childs'), (String) objMap.get('Name'));
            }
            fldList.add(fld);
        }
        return fldList;
    }
    
    
    
    //Settings Tab
    public String selectedAction {get;set;}
    
    public List<SelectOption> getActions() {
        List<SelectOption> actions = new List<SelectOption>();
        actions.add(new SelectOption('nothing','Do Nothing'));
        actions.add(new SelectOption('copy','Copy'));
        actions.add(new SelectOption('move','Move')); 
        return actions;
    }
    
    public void onChange() {
        if(selectedAction.equalsIgnoreCase('nothing')) {
            Drive__c drive = Drive__c.getOrgDefaults();
            if(Schema.sObjectType.Drive__c.isUpdateable() &&
               Schema.sObjectType.Drive__c.isCreateable() &&
               Schema.sObjectType.Drive__c.Fields.Files_Action__c.isUpdateable() &&
               Schema.sObjectType.Drive__c.Fields.Files_Action__c.isCreateable()) {
                   drive.Files_Action__c = 'nothing';
                   upsert drive;
               }
        }
    }
    
    public void apply() {
        token = AuthController.CheckTokenAvailability();
        if(token == null) {
            token = AuthController.getAccessToken();
        }
        
        Database.executeBatch(new FilesActionsClassicBatch(selectedAction, token), 1);
        Database.executeBatch(new FilesActionsBatch(selectedAction, token), 1);
        
        Drive__c drive = Drive__c.getOrgDefaults();
        if(Schema.sObjectType.Drive__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.isCreateable() &&
           Schema.sObjectType.Drive__c.Fields.Files_Action__c.isUpdateable() &&
           Schema.sObjectType.Drive__c.Fields.Files_Action__c.isCreateable()) {
               drive.Files_Action__c = selectedAction;
               upsert drive;
           }
    }
    
    
    public void generatePages() {
        generatedAlertString = 'Pages generated for objects:';
        for(Objects obj : objects) {
            if(obj.Checked) {
                createPage(obj.Name);
                generatedAlertString += ' \n ' + obj.Label;
            }
        }
        //system.debug(generatedAlertString);
    }
    
    
    public void createPage(String objName) {        
        Map<String, String> pageContent = new Map<String, String>();
        pageContent.put('Name', 'FilePane_' + objName.replace('baobab_drive__', '').remove('__c'));
        pageContent.put('ControllerType', '1');
        pageContent.put('MasterLabel', 'FilePane_' + objName.replace('baobab_drive__', '').remove('__c'));
        pageContent.put('ApiVersion', '43.0');
        pageContent.put('Markup', '<apex:page docType="html-5.0" standardController="' + objName + '">\n    <c:FileDraggerClassic recId="{!Id}"/>\n</apex:page>');
        
        String salesforceHost = System.Url.getSalesforceBaseURL().toExternalForm();
        String url =  salesforceHost + '/services/data/v43.0/sobjects/ApexPage';
        
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(url);
        req.setHeader('Content-type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setBody(JSON.serialize(pageContent));
        
        Http http = new Http();
        HTTPResponse res = http.send(req);
        System.debug(res.getBody());
    }
}