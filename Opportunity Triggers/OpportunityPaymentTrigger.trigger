trigger OpportunityPaymentTrigger on Opportunity (after update) {
    // Collect relevant unit IDs first
    Set<Id> relevantUnitIds = new Set<Id>();
    
    for (Opportunity opp : Trigger.new) {
        Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
        
        // Check if Payment_Done has been changed to true
        if (opp.Payment_Done__c == true && 
            oldOpp.Payment_Done__c == false && 
            opp.Unit_Number__c != null &&
            opp.StageName == 'Booked') {
            
            relevantUnitIds.add(opp.Unit_Number__c);
        }
    }
    
    // If no relevant updates, exit early
    if (relevantUnitIds.isEmpty()) {
        return;
    }
    
    try {
        // Query all relevant units in bulk
        Map<Id, Unit__c> unitsMap = new Map<Id, Unit__c>([
            SELECT Id, Unit_Status__c, Blocked_By__c, Blocking_Expiry__c 
            FROM Unit__c 
            WHERE Id IN :relevantUnitIds
        ]);
        
        List<Unit__c> unitsToUpdate = new List<Unit__c>();
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        Set<Id> unitsToAbortJobs = new Set<Id>();
        
        for (Opportunity opp : Trigger.new) {
            Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
            
            if (opp.Payment_Done__c == true && 
                oldOpp.Payment_Done__c == false && 
                opp.Unit_Number__c != null &&
                opp.StageName == 'Booked') {
                
                Unit__c unit = unitsMap.get(opp.Unit_Number__c);
                
                // Check if unit exists and we're still within the 30-minute window
                if (unit != null && unit.Blocking_Expiry__c > System.now()) {
                    // Update unit status
                    unit.Unit_Status__c = 'Sold';
                    unit.Blocked_By__c = null;
                    unit.Blocking_Expiry__c = null;
                    unitsToUpdate.add(unit);
                    
                    // Create new Opportunity instance for update
                    oppsToUpdate.add(new Opportunity(
                        Id = opp.Id,
                        StageName = 'Closed Won'
                    ));
                    
                    // Add to set of jobs to abort
                    unitsToAbortJobs.add(unit.Id);
                }
            }
        }
        
        // Perform bulk updates
        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
        
        if (!unitsToUpdate.isEmpty()) {
            update unitsToUpdate;
        }
        
        
        // Abort scheduled jobs in bulk
        if (!unitsToAbortJobs.isEmpty()) {
            abortScheduledJobs(unitsToAbortJobs);
        }
        
    } catch (Exception e) {
        // Log any errors for debugging
        System.debug('Error in OpportunityPaymentTrigger: ' + e.getMessage());
        throw e;  // Re-throw to maintain visibility of errors
    }
    
    private static void abortScheduledJobs(Set<Id> unitIds) {
        // Build the LIKE patterns for all unit IDs
        List<String> patterns = new List<String>();
        for (Id unitId : unitIds) {
            patterns.add('UnitTimeout_' + unitId + '%');
        }
        
        // Query all relevant jobs in one go
        List<CronTrigger> scheduledJobs = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE :patterns
        ];
        
        // Abort all jobs in bulk
        for (CronTrigger job : scheduledJobs) {
            System.abortJob(job.Id);
        }
    }
}
