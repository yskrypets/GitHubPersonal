({
	getFolders : function(cmp, event, helper) {
        var action = cmp.get('c.getFolders');
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var foldersList = response.getReturnValue();

                foldersList.sort(function(a, b) {
                    var labelA = a.Label.toLowerCase(), labelB = b.Label.toLowerCase();
                    if (labelA < labelB) return -1;
                    if (labelA > labelB) return 1;
                    return 0;
                });
                
                cmp.set('v.folders', foldersList);
                console.log(foldersList);
                var allChecked = true;
                allChecked = this.compareAllChecked(cmp, event, helper, foldersList, allChecked);
                cmp.set('v.selectAll', allChecked);
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
        }));
        $A.enqueueAction(action);
    },
    
    apply : function(cmp, actionValue) {
        var action = cmp.get('c.actionWithFiles');
        action.setParams({ 
            'value' : actionValue
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {}
        }));
        $A.enqueueAction(action);
    },
    
    updateFolders : function(cmp, event, helper) {
        var hlp = this;
        var action = cmp.get('c.updDriveFolders');
        console.log(cmp.get('v.folders'));
        action.setParams({ 
            'folders' : JSON.stringify(cmp.get('v.folders'))
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set('v.folders', response.getReturnValue());
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
        }));
        $A.enqueueAction(action);
    },
    
    showToast : function(component, event, helper, title, type, message) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": message,
            "duration": 30000,
            "type": type
        });
        toastEvent.fire();
    },
    
    checkAll: function(cmp, event, helper, folders, checked) {
        for(var i = 0; i < folders.length; i++) {
            if(cmp.get('v.selectAll')) {
                if(checked.includes(folders[i].Name)) {
                    cmp.set('v.multiParent', true);
                    folders[i].Checked = false;
                } else {
                    folders[i].Checked = true;
                    checked[checked.length] = folders[i].Name;
                }
            } else {
                folders[i].Checked = false;
            }
            if(folders[i].hasChilds) {
                folders[i].Childs = this.checkAll(cmp, event, helper, folders[i].Childs, checked);
            }
        }
        return folders;
    },
    
    checkObjectTrue: function(cmp, event, helper, folders, checkedObject, parentName) {
        for(var i = 0; i < folders.length; i++) {
            //console.log(folders[i]);
            if(folders[i].Name == checkedObject && event.getSource().get("v.class") == parentName) {
                folders[i].Parent = parentName;
                folders[i].Checked = true;
                return true;
            }
            if(folders[i].hasChilds) {
                var returned = this.checkObjectTrue(cmp, event, helper, folders[i].Childs, checkedObject, folders[i].Name);
                if(returned) {
                    folders[i].Checked = true;
                    return true;
                }
            }
        }
        return false;
    },
    
    checkObjectFalse: function(cmp, event, helper, allChecked, folders, parentCheck) {
        for(var i = 0; i < folders.length; i++) {
            if(parentCheck == false) folders[i].Checked = false;
            if(folders[i].Checked == false) allChecked = false;
            if(folders[i].hasChilds) {
                allChecked = this.checkObjectFalse(cmp, event, helper, allChecked, folders[i].Childs, folders[i].Checked);
            }
        }
        return allChecked;
    },
    
    uncheckSame: function(cmp, event, helper, folders, parentCheck, shouldUncheck) {
        for(var i = 0; i < folders.length; i++) {
            if(folders[i].Name == parentCheck || shouldUncheck) {
                folders[i].Checked = false;
            }
            if(folders[i].hasChilds) {
                this.uncheckSame(cmp, event, helper, folders[i].Childs, parentCheck, folders[i].Name == parentCheck ? true : false);
            }
        }
    },
    
    compareAllChecked: function(cmp, event, helper, folders, allChecked) {
        for(var i = 0; i < folders.length; i++) {
            if(folders[i].Checked == false) return false;
            if(folders[i].hasChilds) {
                allChecked = this.compareAllChecked(cmp, event, helper, folders[i].Childs, allChecked);
                if(allChecked == false) return false;
            }
        }
        return allChecked;
    },
    
    openCloseChild: function(cmp, event, helper, folders, objName, action) {
        for(var i = 0; i < folders.length; i++) {
            if(folders[i].Name === objName) {
                folders[i].Opened = action;
                return true;
            }
            if(folders[i].hasChilds) {
                var returned = this.openCloseChild(cmp, event, helper, folders[i].Childs, objName, action);
                if(returned) return true;
            }
        }
    }
})