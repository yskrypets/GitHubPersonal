({
    init: function (cmp, event, helper) {
        helper.checkAuthorizing(cmp);
        helper.checkAction(cmp);
        helper.checkSubfolders(cmp);
    },
    
	apply: function (cmp, event, helper) {
        helper.apply(cmp, event, helper, cmp.get('v.actionValue'));
    },
    
    handleChangeAction: function (cmp, event, helper) {
        var changeValue = event.getParam("value");
        if(changeValue == 'nothing') {
            helper.saveAction(cmp, changeValue);
        }
    },
    
    showAddSubfolder: function (cmp, event, helper) {
        cmp.set('v.recordTempName', event.target.getAttribute('name'));
        cmp.set('v.showAddSubfolderModal', true);
    },
    
    hideAddSubfolder: function (cmp, event, helper) {
        cmp.set('v.recordTempName', '');
        cmp.set('v.subfolderName', '');
        cmp.set('v.showAddSubfolderModal', false);
    },
    
    addSubfolder: function (cmp, event, helper) {
        helper.addSubfolder(cmp);
        cmp.set('v.showAddSubfolderModal', false);
        cmp.set('v.recordTempName', '');
        cmp.set('v.subfolderName', '');
    },
    
    showRemoveSubfolder: function (cmp, event, helper) {
        cmp.set('v.recordTempName', event.target.getAttribute('data-name'));
        cmp.set('v.subfolderName', event.target.getAttribute('data-label'));
        cmp.set('v.confirmRemoveModal', true);
    },
    
    hideRemoveSubfolder: function (cmp, event, helper) {
        cmp.set('v.recordTempName', '');
        cmp.set('v.subfolderName', '');
        cmp.set('v.confirmRemoveModal', false);
    },
    
    removeSubfolder: function (cmp, event, helper) {
        helper.removeSubfolder(cmp);
        cmp.set('v.confirmRemoveModal', false);
        cmp.set('v.recordTempName', '');
        cmp.set('v.subfolderName', '');
    }
})