({
    checkAuth : function(cmp) {
        var action = cmp.get('c.checkAuthorizingWithoutSave');
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var resp = response.getReturnValue();
                cmp.set('v.authorized', resp.auth);
                cmp.set('v.access', resp.access);
            } else if (state === "ERROR") {
                cmp.set('v.authorized', false);
            }
        }));
        $A.enqueueAction(action);
    },
    
    
	authorize : function(component, event) {
		var action = component.get("c.authDrive");
        action.setParams({ 
            'externalDriveName' : event.getParam("value")
        });
        action.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS") {
                window.location.href = response.getReturnValue();
            }
        });
        $A.enqueueAction(action);
	},
    
    
    clear : function(component) {
		var action = component.get("c.clearDeleted");
        action.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS") {}
        });
        $A.enqueueAction(action);
	},
    
    
    remove : function(component) {
		var action = component.get("c.clearArchivedFolder");
        action.setCallback(this, function(response){
            var state = response.getState();
            component.set('v.spinner','slds-spinner_container slds-hide');
            if (state === "SUCCESS") {
                this.showToast(component, 'Removal process has been completed.', 'warning', 'All files from the Archived folder have been deleted.');
            }
        });
        $A.enqueueAction(action);
	},
    
    
    logOut : function(component) {
		var action = component.get("c.logOutDrive");
        action.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set('v.authorized', false);
            } else if (state === "ERROR") {
                console.error(response.getReturnValue());
            }
        });
        $A.enqueueAction(action);
	},
    
    
    showToast : function(component, title, type, message) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": message,
            "duration": 30000,
            "type": type
        });
        toastEvent.fire();
    },
})