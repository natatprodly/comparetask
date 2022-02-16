trigger ComparisonViewRuleTrigger on ComparsonViewRule__c (after insert, after update, after undelete) {   
    try {
        if( Trigger.isAfter ) {       
            if( Trigger.isInsert || Trigger.isUdate || Trigger.isUndelete ) {      
                ComparisoViewRuleTriggerHelper.validateRulesAfter(Trigger.new);
            }
        }   
    } catch(Exception e) {
        System.debug('Error while inserting/updating copaison view rules ' + 
            e.getMessage() + ' : ' + e.getStackTraceString());
    }
    
}
