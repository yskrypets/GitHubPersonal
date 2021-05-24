({
    init: function (cmp, event, helper) {
        helper.getFolders(cmp, event, helper);
    },
    
    apply: function (cmp, event, helper) {
        helper.apply(cmp, cmp.get('v.actionValue'));
    },
    
    checkAll: function(cmp, event, helper) {
        var folders = cmp.get('v.folders');
        folders = helper.checkAll(cmp, event, helper, folders, []);
        if(cmp.get('v.multiParent')) {
            helper.showToast(cmp, event, helper, 'Multi parents', 'warning', 'Some objects have few parents.');
            cmp.set('v.multiParent', false);
        }
        cmp.set('v.folders', folders);
    },
    
    checkObject: function(cmp, event, helper) {
        var isCheck = event.getSource().get("v.value");
        var folders = cmp.get('v.folders');
        var allChecked = true;
        var checkedObject = event.getSource().get("v.name");
        if(isCheck) {
            helper.uncheckSame(cmp, event, helper, folders, checkedObject, false);
        	helper.checkObjectTrue(cmp, event, helper, folders, checkedObject, '');
			allChecked = helper.compareAllChecked(cmp, event, helper, folders, allChecked);
        } else {
            allChecked = helper.checkObjectFalse(cmp, event, helper, allChecked, folders, true);
        }
        cmp.set('v.folders', folders);
        cmp.set('v.selectAll', allChecked);
    },
    
    
    showConfirmation: function(cmp, event, helper) {
        document.getElementById('modalContainer').setAttribute('style','');
    },
    
    hideConfirmation: function(cmp, event, helper) {
        document.getElementById('modalContainer').setAttribute('style','display:none;');
    },
    
    updateFolders: function(cmp, event, helper) {
        document.getElementById('modalContainer').setAttribute('style','display:none;');
        helper.updateFolders(cmp, event, helper);
    },
    
    openChild: function(cmp, event, helper) {
        var objName = event.getSource().get("v.value");
        var folders = cmp.get('v.folders');
        
        helper.openCloseChild(cmp, event, helper, folders, objName, true);
        
        cmp.set('v.folders', folders);
    },
    
    closeChild: function(cmp, event, helper) {
        var objName = event.getSource().get("v.value");
        var folders = cmp.get('v.folders');
        
        helper.openCloseChild(cmp, event, helper, folders, objName, false);
        
        cmp.set('v.folders', folders);
    }
})