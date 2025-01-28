public class BookingTimeoutManager {
    public static void scheduleUnitTimeouts(List<Id> unitIds) {
        if (unitIds == null || unitIds.isEmpty()) return;
        
        // Process units in batches of 50 to reduce scheduled jobs
        List<List<Id>> batchedUnits = new List<List<Id>>();
        List<Id> currentBatch = new List<Id>();
        
        for (Id unitId : unitIds) {
            currentBatch.add(unitId);
            if (currentBatch.size() == 50) {
                batchedUnits.add(currentBatch);
                currentBatch = new List<Id>();
            }
        }
        if (!currentBatch.isEmpty()) {
            batchedUnits.add(currentBatch);
        }
        
        Datetime scheduleTime = System.now().addMinutes(30);
        
        for (List<Id> batch : batchedUnits) {
            String jobName = 'UnitTimeout_Batch_' + System.currentTimeMillis();
            String cronExp = String.format(
                '{0} {1} {2} {3} {4} ? {5}',
                new String[]{
                    String.valueOf(scheduleTime.second()),
                    String.valueOf(scheduleTime.minute()),
                    String.valueOf(scheduleTime.hour()),
                    String.valueOf(scheduleTime.day()),
                    String.valueOf(scheduleTime.month()),
                    String.valueOf(scheduleTime.year())
                }
            );
            
            try {
                System.schedule(jobName, cronExp, new UnitTimeoutSchedulable(batch));
            } catch (Exception e) {
                System.debug('Failed to schedule timeout for batch: ' + e.getMessage());
            }
        }
    }
}
