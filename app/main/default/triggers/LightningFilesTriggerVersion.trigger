trigger LightningFilesTriggerVersion on ContentVersion (after insert) {
	String action = Drive__c.getOrgDefaults().Files_Action__c;
    if(action != null && action != 'nothing') {
        LightningFilesTriggerHandler.checkAction(JSON.serialize(Trigger.newMap.keySet()));
    }
}