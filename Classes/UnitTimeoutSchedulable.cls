public class UnitTimeoutSchedulable implements Schedulable {
    private List<Id> unitIds;
    
    public UnitTimeoutSchedulable(List<Id> unitIds) {
        this.unitIds = unitIds;
    }
    
    public void execute(SchedulableContext ctx) {
        if (unitIds == null || unitIds.isEmpty()) {
            return;
        }
        
        // Since we're scheduling one job per unit, we should only have one ID
        Id unitId = unitIds[0];
        
        try {
            // Query the Unit and related Opportunity
            Unit__c unit = [SELECT Id, Unit_Status__c, Blocked_By__c, Blocking_Expiry__c 
                          FROM Unit__c 
                          WHERE Id = :unitId 
                          LIMIT 1];
                           
            List<Opportunity> relatedOpps = [SELECT Id, StageName, Payment_Done__c 
                                           FROM Opportunity 
                                           WHERE Unit_Number__c = :unitId 
                                           AND StageName = 'Booked'
                                           LIMIT 1];
            
            if (!relatedOpps.isEmpty()) {
                Opportunity opp = relatedOpps[0];
                
                // Double check payment status at timeout
                if (opp.Payment_Done__c) {
                    // Payment was completed - mark as sold
                    unit.Unit_Status__c = 'Sold';
                    opp.StageName = 'Closed Won';
                } else {
                    // No payment - reset unit to Available
                    unit.Unit_Status__c = 'Available';
                    opp.StageName = 'Closed Lost';
                }
                
                // Clear blocking fields
                unit.Blocked_By__c = null;
                unit.Blocking_Expiry__c = null;
                
                // Update Both Unit And Opportunity
                update unit;
                update opp;
            } else {
                // If no related opportunity found, just reset the unit
                unit.Unit_Status__c = 'Available';
                unit.Blocked_By__c = null;
                unit.Blocking_Expiry__c = null;
                update unit;
            }
            
        } catch (Exception e) {
            System.debug('Error processing timeout for unit ' + unitId + ': ' + e.getMessage());
        } finally {
            // Aborting the Job after Processing
            System.abortJob(ctx.getTriggerId());
        }
    }
}
