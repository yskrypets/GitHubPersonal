({
    checkAuthorizing : function(cmp) {
        var action = cmp.get('c.checkAuthorizing');
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var resp = response.getReturnValue();
                cmp.set('v.authorized', resp.auth);
            } else if (state === "ERROR") {
                cmp.set('v.authorized', false);
            }
        }));
        $A.enqueueAction(action);
    },
    
    checkAction : function(cmp) {
        var action = cmp.get('c.checkFilesAction');
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set('v.actionValue', response.getReturnValue());
            }
        }));
        $A.enqueueAction(action);
    },
    
    checkSubfolders : function(cmp) {
        var action = cmp.get('c.fillSubfolders');
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set('v.subfolders', JSON.parse(response.getReturnValue()));
            }
        }));
        $A.enqueueAction(action);
    },
    
    addSubfolder : function(cmp) {
        var action = cmp.get('c.addSubfolderCtrl');
        action.setParams({ 
            'recordTempName' : cmp.get('v.recordTempName'),
            'subfolderName' : cmp.get('v.subfolderName')
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set('v.subfolders', JSON.parse(response.getReturnValue()));
            }
        }));
        $A.enqueueAction(action);
    },
    
    removeSubfolder : function(cmp) {
        var action = cmp.get('c.removeSubfolderCtrl');
        action.setParams({ 
            'recordTempName' : cmp.get('v.recordTempName'),
            'subfolderName' : cmp.get('v.subfolderName')
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set('v.subfolders', JSON.parse(response.getReturnValue()));
            }
        }));
        $A.enqueueAction(action);
    },
    
	apply : function(cmp, event, helper, actionValue) {
        this.showToast(cmp, event, helper, 'You have initiated the "' + actionValue + '" action.', 'info', 'You will receive an email when this action is completed.');
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
    
    saveAction : function(cmp, actionValue) {
        var action = cmp.get('c.saveActionWithFiles');
        action.setParams({ 
            'value' : actionValue
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {}
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
    }
})