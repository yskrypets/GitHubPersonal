trigger LeadConversation on Lead (after update) {
    Set<String> leadIds = new Set<String>();
    for(String key : Trigger.newMap.keySet()) {
        if(Trigger.newMap.get(key).isConverted != Trigger.oldMap.get(key).isConverted) {
            leadIds.add(key);
        }
    }
    if(!leadIds.isEmpty()) {
        List<Lead> leadList = [SELECT id, Name, ConvertedAccountId, ConvertedContactId, ConvertedContact.Name FROM Lead WHERE id IN: leadIds];
        try {
            FilesController.moveFilesUponLeadConversion(JSON.serialize(leadList));
        } catch(Exception e) {system.debug(e);}
    }
}