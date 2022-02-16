trigger ComparisonViewRuleTrigger on ComparisonViewRule__c (after insert, after update, after undelete) {   
    try {
        if( Trigger.isAfter ) {       
            if( Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete ) {      
                ComparisonViewRuleTriggerHelper.validateRulesAfter(Trigger.new);
            }
        }   
    } catch(Exception e) {
        System.debug('Error while inserting/updating comparison view rules ' + 
            e.getMessage() + ' : ' + e.getStackTraceString());
    }
    
}