trigger ClassicFilesTrigger on Attachment (after insert) {
    List<Attachment> attList = new List<Attachment>();
    for(Attachment att : Trigger.new) {
        if(att.BodyLength <= 6291456) {
            attList.add(att);
        }
    }
    ClassicFilesTriggerHandler.checkAction(JSON.serialize(attList));
}