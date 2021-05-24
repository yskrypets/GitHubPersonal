({
    init: function (cmp, event, helper) {
        helper.checkAuth(cmp);
    },
    
    authorize : function(component, event, helper) {
        helper.authorize(component, event);
    },
    
    clear : function(component, event, helper) {
        helper.showToast(component, 'Clearing process.', 'info', 'You have begun archiving deleted records from Drive.');
        helper.clear(component);
    },
    
    showConfirmation1 : function(component, event, helper) {
        component.set('v.removeContainer', true);
    },
    
    hideConfirmation1 : function(component, event, helper) {
        component.set('v.removeContainer', false);
    },
    
    showConfirmation2 : function(component, event, helper) {
        component.set('v.logoutContainer', true);
    },
    
    hideConfirmation2 : function(component, event, helper) {
        component.set('v.logoutContainer', false);
    },
    
    remove : function(component, event, helper) {
        component.set('v.removeContainer', false);
        component.set('v.spinner','slds-spinner_container');
        helper.remove(component);
    },
    
    logOut : function(component, event, helper) {
        helper.logOut(component);
        component.set('v.logoutContainer', false);
    }
})