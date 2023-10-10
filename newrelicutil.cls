public class NewRelicUtils {
    private static Logger logger = LoggerFactory.getLogger(NewRelicUtils.CLASS);
    private static final String API_KEY = 'xxxxx';
    private static final String TRACE_API_ENDPOINT = 'https://trace-api.newrelic.com/trace/v1';

    public static String generateRandomString(Integer len) {
        final String chars = '0123456789abcdef';
        String traceidStr = '';
        while (traceidStr.length() < len) {
           Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
           traceidStr += chars.substring(idx, idx+1);
        }
        return traceidStr;
    }

    public static String generateTraceParent(String traceID, String spanID) {
        return '00-'+ traceID + '-' + spanID +'-01';
    }

    public static string getTraceIdFromTraceparent(String traceparent) {
        List<String> splitTraceparentParts = traceParent.split('-');
        if (!splitTraceparentParts.isEmpty()) {
            return splitTraceparentParts[1];
        }
        return '';
    }

    public static string getSpanIdFromTraceparent(String traceparent) {
        List<String> splitTraceparentParts = traceParent.split('-');
        if (!splitTraceparentParts.isEmpty()) {
            return splitTraceparentParts[2];
        }
        return '';
    }
    
    public static void generateNRParams(Map<String, String> nrParamsMap){
        logger.info('Entering into the generateNRParams');

        DateTime dt = DateTime.newInstance(2007, 6, 23, 3, 3, 3);
        Long currentTimeMill = dt.getTime();
        String sTraceID = '';
        String sParentSpanID = '';

	    integer iSpanIDLength = 16;
    	String sSpanID = generateRandomString(iSpanIDLength);
        /*
         * For Inbound API traceparent will be coming from the headers request. We can split the
         * traceparent and grab the traceId instead generate new one.
        */
        if (nrParamsMap.containsKey('traceparent')) {
            String traceparentInput = OrderingUtil.getString('traceparent', nrParamsMap);
            sTraceID = getTraceIdFromTraceparent(traceparentInput);
            sParentSpanID = getSpanIdFromTraceparent(traceparentInput);
            nrParamsMap.remove('traceparent'); // Removing the traceparent key from the nrParamsMap.
        } else {
            integer iTraceLength = 32;
            sTraceID = generateRandomString(iTraceLength);
        }     

        String traceparent = generateTraceParent(sTraceID,sSpanID);

       
          String headerDT = '{\n' +
        '\"d\": {\n' +
       '\"ac\": \"xxxxxx\",\n' +
       '\"pr\": 1.073175,\n' +
       '\"tx\": \"'+sTraceID+ '\",\n' +
       '\"ti\": '+ currentTimeMill + ',\n'+
       '\"ty\": \"App\",\n'      +
       '\"tk\": \"xxxxxxxx\",\n' +
       '\"id\": \"'+sSpanID+ '\",\n' +
       '\"tr\": \"'+sTraceID+ '\",\n' +  
       '\"sa\": true,\n' +  
       '\"ap\": \"xxxxxxxxx\"\n' +
    '},\n' +      
    '\"v\": [0,1]\n' +
'}';        

        // create a blob from our parameter value before we send it as part of the url
        Blob NRHeaderblob = Blob.valueOf(headerDT);
        // base64 encode the blob that contains our url param value
        string NRHeader = EncodingUtil.base64Encode(NRHeaderblob);

        nrParamsMap.put('newrelic', NRHeader);
        nrParamsMap.put('traceparent', traceparent);
        nrParamsMap.put('sTraceID', sTraceID);
        nrParamsMap.put('sSpanID', sSpanID);
        nrParamsMap.put('sParentSpanID', sParentSpanID);

        logger.info('Exiting generateNRParams with outputMap'+nrParamsMap);
    }


    @future(callout=true)
    public static void invokeTraceAPI(Map<String, String> inputMap) {
        // String correlationId, String sTraceID, String sSpanID
        logger.info('Entering into the invokeTraceAPI with the parameters inputMap' +inputMap);
        String apiName = Util.getString('apiName',inputMap);
        String serviceName = gUtil.getString('serviceName',inputMap);
        String sTraceID = Util.getString('sTraceID',inputMap);
        String sSpanID = Util.getString('sSpanID',inputMap);
        String correlationId = Util.getString('correlationId',inputMap);
        String statusCode = Util.getString('statusCode',inputMap);
        String success = Util.getString('success',inputMap);
        String sParentSpanID = Util.getString('sParentSpanID',inputMap);
       

        //Zipkin Json
        String payload= '[\n'+
        '            {\n'+
        '               "traceId": "' + sTraceID +'",\n';
        if (!String.isEmpty(sParentSpanID)) {
            payload = payload + '               "parentId": "' + sParentSpanID +'",\n';
        }
        payload = payload +
        '               "id": "' + sSpanID + '",\n' +
        '               "kind": "SERVER",\n' +
        '               "name": "'+ apiName +'",\n' +
      //  '               "duration": ' + lDuration + ',\n' +
        '               "localEndpoint": {\n' +
        '                   "serviceName": "SF",\n' +
        '                   "ipv4": "newrelic-e-dev-ed.my.salesforce.com",\n' +
        '                   "port": 8080\n' +
        '                },\n' +
        '               "tags": {\n'+
        '                    "statusCode": "' + statusCode + '",\n'+
        '                    "success": "' + success + '"\n'+
        '               }\n'+
        '            }\n'+
        ']';
        HttpResponse httpResponse = new HttpResponse();
        Map<String, String> queryParams = new Map<String, String>();
        // HEADERS
        Map<String, String> headers = new Map<String, String>{
          'Content-Type' => 'application/json;charset=UTF-8',
          'Api-Key' => API_KEY,
          'Data-Format' => 'zipkin',
          'Data-Format-Version' => '2'
        };
        SYS_CalloutService.CalloutProperties calloutProperties = new SYS_CalloutService.CalloutProperties();
        logger.info('perform call : NR Trace API');
        httpResponse = SYS_CalloutService.getInstance().performHttpCallout(null, TRACE_API_ENDPOINT, SYS_CalloutService.HTTP_METHODS.POST, headers, payload, queryParams, calloutProperties);
        if (httpResponse != null) {
            logger.info('Exiting from the invokeTraceAPI Response status : ' + httpResponse.getStatus() + ' Code : ' + httpResponse.getStatusCode());
            logger.info('Exiting from the invokeTraceAPI response body ' + httpResponse.getBody());
        }
    }
}