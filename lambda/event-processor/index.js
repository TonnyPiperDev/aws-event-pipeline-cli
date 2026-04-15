exports.handler = async (event) => {
    console.log('Received event:', JSON.stringify(event, null, 2));
    
    // Extract event details
    const eventType = event['detail-type'] || 'Unknown';
    const eventSource = event.source || 'Unknown';
    const eventTime = event.time || new Date().toISOString();
    
    console.log(`Processing ${eventType} from ${eventSource} at ${eventTime}`);
    
    // Simulate processing
    const result = {
        statusCode: 200,
        body: JSON.stringify({
            message: 'Event processed successfully',
            eventType: eventType,
            processedAt: new Date().toISOString()
        })
    };
    
    return result;
};
