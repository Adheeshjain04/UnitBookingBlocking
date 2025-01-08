// Trigger to handle payment status updates
trigger OpportunityPaymentTrigger on Opportunity (after update) {
    List<Unit__c> unitsToUpdate = new List<Unit__c>();
    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    
    for (Opportunity opp : Trigger.new) {
        Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
        
        // Check if Payment_Done has been changed to true
        if (opp.Payment_Done__c == true && 
            oldOpp.Payment_Done__c == false && 
            opp.Unit_Number__c != null &&
            opp.StageName == 'Booked') {
            
            // Query for the related Unit
            Unit__c unit = [SELECT Id, Unit_Status__c, Blocked_By__c, Blocking_Expiry__c 
                          FROM Unit__c 
                          WHERE Id = :opp.Unit_Number__c 
                          LIMIT 1];
            
            // Check if we're still within the 30-minute window
            if (unit.Blocking_Expiry__c > System.now()) {
                // Update unit status
                unit.Unit_Status__c = 'Sold';
                unit.Blocked_By__c = null;
                unit.Blocking_Expiry__c = null;
                unitsToUpdate.add(unit);
                
                // Create new Opportunity instance for update
                Opportunity oppToUpdate = new Opportunity(
                    Id = opp.Id,
                    StageName = 'Closed Won'
                );
                oppsToUpdate.add(oppToUpdate);
                
                // Find and abort the scheduled job
                abortScheduledJob(unit.Id);
            }
        }
    }
    
    // Update records
    if (!unitsToUpdate.isEmpty()) {
        update unitsToUpdate;
    }
    if (!oppsToUpdate.isEmpty()) {
        update oppsToUpdate;
    }
    
    private static void abortScheduledJob(Id unitId) {
        // Query for scheduled jobs related to this unit
        List<CronTrigger> scheduledJobs = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE :('UnitTimeout_' + unitId + '%')
        ];
        
        // Abort the scheduled jobs
        for (CronTrigger job : scheduledJobs) {
            System.abortJob(job.Id);
        }
    }
}
