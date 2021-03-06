/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/


#import "NavWebviewHelper.h"
#import "NavJSNativeHandler.h"
#import "Logging.h"
#import "LocationEvent.h"
#import "NavDeviceTTS.h"
#import <Mantle/Mantle.h>

#define LOADING_TIMEOUT 30

#define UI_PAGE @"%@://%@/%@mobile.jsp?noheader&noclose&id=%@"
//#define UI_PAGE @"%@://%@/%@mobile.html?noheader" // for backward compatibility
// does not work with old server


// override UIWebView accessibility to prevent reading Map contents
@implementation NavWebView

- (BOOL)isAccessibilityElement
{
    return NO;
}

- (NSArray *)accessibilityElements
{
    return nil;
}

- (NSInteger)accessibilityElementCount
{
    return 0;
}

@end

@implementation NavWebviewHelper {
    UIWebView *webView;
    NavJSNativeHandler *handler;
    NSString *callback;
    BOOL bridgeHasBeenInjected;
    NSTimeInterval lastLocationSent;
    NSTimeInterval lastOrientationSent;
    NSTimeInterval lastRequestTime;
    
    NSURLRequest *currentRequest;
}

- (void)dealloc {
    webView = nil;
    handler = nil;
    callback = nil;
}

- (void)prepareForDealloc
{
    [handler prepareForDealloc];
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self name:TRIGGER_WEBVIEW_CONTROL object:nil];

    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"developer_mode"];
}

- (instancetype) initWithWebview:(UIWebView *)view {
    self = [super init];
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    if ([ud boolForKey: @"cache_clear"]) {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [ud setBool:NO forKey:@"cache_clear"];
    }
    
    _isReady = NO;
    
    webView = view;
    webView.delegate = self;
    webView.scrollView.bounces = NO;
    webView.suppressesIncrementalRendering = YES;
    //webView.scrollView.scrollEnabled = NO;
    
    [self loadUIPage];
    
    handler = [[NavJSNativeHandler alloc] init];
    [handler registerWebView:webView];
    
    [handler registerFunc:^(NSDictionary *param, UIWebView *webView) {
        NSString *text = [param objectForKey:@"text"];
        BOOL flush = [[param objectForKey:@"flush"] boolValue];
        [[NavDeviceTTS sharedTTS] speak:text withOptions:@{@"force":@(flush)} completionHandler:nil];
    } withName:@"speak" inComponent:@"SpeechSynthesizer"];
    
    [handler registerFunc:^(NSDictionary *param, UIWebView *wv) {
        NSString *result = [[NavDeviceTTS sharedTTS] isSpeaking]?@"true":@"flase";
        NSString *name = param[@"callbackname"];
        [wv stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@.%@(%@)", callback, name, result]];
    } withName:@"isSpeaking" inComponent:@"SpeechSynthesizer"];
    [handler registerFunc:^(NSDictionary *param, UIWebView *wv) {
        if ([param objectForKey:@"value"]) {
            callback = [param objectForKey:@"value"];
            //NSLog(@"callback method is %@", callback);
            [self updatePreferences];
        }
    } withName:@"callback" inComponent:@"Property"];
    [handler registerFunc:^(NSDictionary *param, UIWebView *wv) {
        [[NSNotificationCenter defaultCenter] postNotificationName:MANUAL_LOCATION_CHANGED_NOTIFICATION object:self userInfo:param];
    } withName:@"mapCenter" inComponent:@"Property"];
    
    [handler registerFunc:^(NSDictionary *param, UIWebView *wv) {
        NSString *result = @"寿司";
        NSString *name = param[@"callbackname"];
        [wv stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@.%@(['%@'])", callback, name, result]];
    } withName:@"startRecognizer" inComponent:@"STT"];
    
    [handler registerFunc:^(NSDictionary *param, UIWebView *webView) {
        NSString *text = param[@"text"];
        //NSLog(@"%@", text);
        
        if ([text rangeOfString:@"getRssiBias,"].location == 0) {
            
            NSData *data = [[text substringFromIndex:[@"getRssiBias," length]] dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *param = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_RSSI_BIAS object:self userInfo:param];
        } else {
            if ([text rangeOfString:@"buildingChanged,"].location == 0) {
                NSData *data = [[text substringFromIndex:[@"buildingChanged," length]] dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *param = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:BUILDING_CHANGED_NOTIFICATION object:self userInfo:param];
            }
            if ([text rangeOfString:@"stateChanged,"].location == 0) {
                NSData *data = [[text substringFromIndex:[@"stateChanged," length]] dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *param = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:WCUI_STATE_CHANGED_NOTIFICATION object:self userInfo:param];
            }
            if ([text rangeOfString:@"navigationFinished,"].location == 0) {
                NSData *data = [[text substringFromIndex:[@"navigationFinished," length]] dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *param = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_RATING object:self userInfo:param];
            }
            if ([Logging isLogging]) {
                NSLog(@"%@", text);
            }
        }
    } withName:@"log" inComponent:@"System"];
    
    [handler registerFunc:^(NSDictionary *param, UIWebView *webView) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    } withName:@"vibrate" inComponent:@"AudioServices"];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerWebviewControl:) name:TRIGGER_WEBVIEW_CONTROL object:nil];    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(destinationChanged:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeChanged:) name:ROUTE_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeCleared:) name:ROUTE_CLEARED_NOTIFICATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(manualLocation:) name:MANUAL_LOCATION object:nil];

    // crash
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveLocation:) name:REQUEST_LOCATION_SAVE object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestStartDialog:) name:REQUEST_START_DIALOG object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestShowRoute:) name:REQUEST_PROCESS_SHOW_ROUTE object:nil];
    
    
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"developer_mode" options:NSKeyValueObservingOptionNew context:nil];
    
    
    return self;
}

#pragma mark - notification handlers

- (void) manualLocation: (NSNotification*) note
{
    HLPLocation* loc = [note userInfo][@"location"];
    BOOL sync = [[note userInfo][@"sync"] boolValue];
    
    NSMutableString* script = [[NSMutableString alloc] init];
    if (loc && !isnan(loc.floor) ) {
        int ifloor = round(loc.floor<0?loc.floor:loc.floor+1);
        [script appendFormat:@"$hulop.indoor.showFloor(%d);", ifloor];
    }
    [script appendFormat:@"$hulop.map.setSync(%@);", sync?@"true":@"false"];
    if (loc) {
        [script appendFormat:@"var map = $hulop.map;"];
        [script appendFormat:@"map.setCenter([%f,%f]);",loc.lng,loc.lat];
    } else {
        [script appendFormat:@"var map = $hulop.map"];
        [script appendFormat:@"var c = map.getCenter();"];
        [script appendFormat:@"map.setCenter(c);"];        
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self evalScript:script];
    });
}

- (void) locationChanged: (NSNotification*) note
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateBackground || state == UIApplicationStateInactive) {
        return;
    }

    NSDictionary *locations = [note userInfo];
    if (!locations) {
        return;
    }
    HLPLocation *location = locations[@"current"];
    if (!location || [location isEqual:[NSNull null]]) {
        return;
    }

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    double orientation = -location.orientation / 180 * M_PI;
    
    if (lastOrientationSent + 0.2 < now) {
        [self sendData:@[@{
                             @"type":@"ORIENTATION",
                             @"z":@(orientation)
                             }]
              withName:@"Sensor"];
        lastOrientationSent = now;
    }
    
    
    location = locations[@"actual"];
    if (!location || [location isEqual:[NSNull null]]) {
        return;
    }
    
    /*
    if (isnan(location.lat) || isnan(location.lng)) {
        return;
    }
    */
    
    if (now < lastLocationSent + [[NSUserDefaults standardUserDefaults] doubleForKey:@"webview_update_min_interval"]) {
        if (!location.params) {
            return;
        }
        //return; // prevent too much send location info
    }
    
    double floor = location.floor;

    [self sendData:@{
                     @"lat":@(location.lat),
                     @"lng":@(location.lng),
                     @"floor":@(floor),
                     @"accuracy":@(location.accuracy),
                     @"rotate":@(0), // dummy
                     @"orientation":@(999), //dummy
                     @"debug_info":location.params?location.params[@"debug_info"]:[NSNull null],
                     @"debug_latlng":location.params?location.params[@"debug_latlng"]:[NSNull null]
                     }
          withName:@"XYZ"];

    lastLocationSent = now;
}

- (void)triggerWebviewControl:(NSNotification*) note
{
    NSDictionary *object = [note userInfo];
    if ([object[@"control"] isEqualToString: ROUTE_SEARCH_OPTION_BUTTON]) {
        [self evalScript:@"$('a[href=\"#settings\"]').click()"];
    }
    else if ([object[@"control"] isEqualToString: ROUTE_SEARCH_BUTTON]) {
        [self evalScript:@"$('a[href=\"#control\"]').click()"];
    }
    else if ([object[@"control"] isEqualToString: DONE_BUTTON]) {
        [self evalScript:@"$('div[role=banner]:visible a').click()"];
    }
    else if ([object[@"control"] isEqualToString: END_NAVIGATION]) {
        [self evalScript:@"$('#end_navi').click()"];
    }
    else if ([object[@"control"] isEqualToString: BACK_TO_CONTROL]) {
        [self evalScript:@"$('div[role=banner]:visible a').click()"];
    }
    else {
        [self evalScript:@"$hulop.map.resetState()"];
        //[self evalScript:@"$('a[href=\"#map-page\"]:visible').click()"];
    }
}

- (void) destinationChanged: (NSNotification*) note
{
    [self initTarget:[note userInfo][@"destinations"]];
}

- (void)initTarget:(NSArray *)landmarks
{
    NSMutableArray *temp = [@[] mutableCopy];
    NSError *error;
    for(id obj in landmarks) {
        [temp addObject:[MTLJSONAdapter JSONDictionaryFromModel:obj error:&error]];
    }
    
    if ([temp count] == 0) {
        //NSLog(@"No Landmarks %@", landmarks);
        return;
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"landmarks":temp} options:0 error:nil];
    NSString *dataStr = [[NSString alloc] initWithData:data  encoding:NSUTF8StringEncoding];
    
    NSString *script = [NSString stringWithFormat:@"$hulop.map.initTarget(%@, null)", dataStr];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [webView stringByEvaluatingJavaScriptFromString:script];
    });
}


- (void) routeChanged: (NSNotification*) note
{
    //[self showRoute:[notification object]];
}

- (void) routeCleared: (NSNotification*) note
{
    [self clearRoute];
}

- (void)clearRoute
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [webView stringByEvaluatingJavaScriptFromString:@"$hulop.map.clearRoute()"];
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"developer_mode"]) {
        [self updatePreferences];
    }
}

# pragma mark - private methods

- (void)loadUIPage {
    NSLog(@"loadUIPage");
    NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:@"selected_hokoukukan_server"];
    NSString *context = [[NSUserDefaults standardUserDefaults] stringForKey:@"hokoukukan_server_context"];
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *device_id = [[UIDevice currentDevice].identifierForVendor UUIDString];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:UI_PAGE, https, server, context, device_id]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [webView loadRequest: request];
    currentRequest = request;
    lastRequestTime = [[NSDate date] timeIntervalSince1970];
}

- (void)loadUIPageWithHash:(NSString*)hash {
    NSString *script = [NSString stringWithFormat:@"location.hash=\"%@\"", hash];
    [self evalScript:script];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:@"selected_hokoukukan_server"];
    NSRange range = [request.URL.absoluteString rangeOfString:server];
    if (range.location == NSNotFound) {
        // TODO
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_OPEN_URL
                                                            object:self userInfo:@{@"url":request.URL}];
        return NO;
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    NSLog(@"webViewDidStartLoad");
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(waitForReady:) userInfo:nil repeats:YES];
    [self.delegate startLoading];
}

- (void) waitForReady:(NSTimer*)timer
{
    NSString *ret = [webView stringByEvaluatingJavaScriptFromString:@"(function(){return window.$hulop.mobile_ready != undefined && document.readyState != 'loading'})();"];
    
    if ([ret isEqualToString:@"true"]) {
        [timer invalidate];
        [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(insertBridge:) userInfo:nil repeats:YES];
        return;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - lastRequestTime > LOADING_TIMEOUT) {
        [timer invalidate];
        [webView stopLoading];
        [self.delegate checkConnection];
    }
}

- (void) insertBridge:(NSTimer*)timer
{
    NSLog(@"insertBridge,%@", callback);
    if (callback != nil) { // check if "callback" string is available
        [timer invalidate];
        if ([self.delegate respondsToSelector:@selector(bridgeInserted)]) {
            [self.delegate bridgeInserted];
        }
    }

    NSString *path = [[NSBundle mainBundle] pathForResource:@"ios_bridge" ofType:@"js"];
    NSString *script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    
    [webView stringByEvaluatingJavaScriptFromString:script];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView2
{
    int status = [[[webView2 request] valueForHTTPHeaderField:@"Status"] intValue];
    
    NSLog(@"webViewDidFinishLoad %d %@", status, webView2.request.URL.absoluteString);
    if (status == 404) {
    }
    [self.delegate loaded];
    _isReady = YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"%@", error);
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self loadUIPage];
    });
}


# pragma mark - public methods

- (NSObject*) removeNaNValue:(NSObject*)obj
{
    NSObject* newObj;
    if ([obj isKindOfClass:NSArray.class]) {
        NSArray* arr = (NSArray*) obj;
        NSMutableArray* newArr = [arr mutableCopy];
        for(int i=0; i<[arr count]; i++){
            NSObject* tmp = arr[i];
            newArr[i] = [self removeNaNValue:tmp];
        }
        newObj = (NSObject*) newArr;
    }else if ([obj isKindOfClass:NSDictionary.class]) {
        NSDictionary* dict = (NSDictionary*) obj;
        NSMutableDictionary* newDict = [dict mutableCopy];
        for(id key in [dict keyEnumerator]){
            NSObject* val = dict[key];
            if([val isKindOfClass:NSNumber.class]){
                double dVal = [(NSNumber*) val doubleValue];
                if(isnan(dVal)){
                    [newDict removeObjectForKey:key];
                }
            }
        }
        newObj = (NSObject*) newDict;
    }
    return newObj;
}

- (void) sendData:(NSObject*)data withName:(NSString*) name
{
    if (callback == nil) {
        return;
    }
    
    data = [self removeNaNValue:data];
    
    NSString *jsonstr = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:data options:0 error:nil]encoding:NSUTF8StringEncoding];
    
    NSString *script = [NSString stringWithFormat:@"%@.onData('%@',%@);", callback, name, jsonstr];
    //NSLog(@"%@", script);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [webView stringByEvaluatingJavaScriptFromString:script];
    });

}

- (void)showRoute:(NSArray *)route
{
    NSMutableArray *temp = [@[] mutableCopy];
    NSError *error;
    for(id obj in route) {
        [temp addObject:[MTLJSONAdapter JSONDictionaryFromModel:obj error:&error]];
    }
    
    if ([temp count] == 0) {
        NSLog(@"No Route %@", route);
        return;
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:temp options:0 error:nil];
    NSString *dataStr = [[NSString alloc] initWithData:data  encoding:NSUTF8StringEncoding];
    
    NSString *script = [NSString stringWithFormat:@"$hulop.map.showRoute(%@, null, true, true);/*$hulop.map.showResult(true);*/$('#map-page').trigger('resize');", dataStr];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [webView stringByEvaluatingJavaScriptFromString:script];
    });
}


- (void) updatePreferences
{
    if (callback == nil) {
        return;
    }
    
    NSArray *keys = @[@"developer_mode", @"user_mode"];
    NSMutableDictionary *data = [@{} mutableCopy];
    for(NSString *key in keys) {
        data[key] = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    }
    NSString *jsonstr = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:data options:0 error:nil]encoding:NSUTF8StringEncoding];
    
    NSString *script = [NSString stringWithFormat:@"%@.onPreferences(%@);", callback, jsonstr];
    //NSLog(@"%@", script);
    dispatch_async(dispatch_get_main_queue(), ^{
        [webView stringByEvaluatingJavaScriptFromString:script];
    });
}


- (void)setBrowserHash:(NSString *)hash
{
    [self loadUIPageWithHash:hash];
}

- (NSString *)evalScript:(NSString *)script
{
    //NSLog(@"evalScript(%@)", script);
    return [webView stringByEvaluatingJavaScriptFromString:script];
}

/* crash sometimes with EXC_BAD_ACCESS
- (void)saveLocation:(NSNotificationCenter*)notification
{
    NSString *ret = [self evalScript:@"(function(){return JSON.stringify($hulop.map.getCenter())})();"];
    NSData *data = [ret dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *loc = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if(loc) {
        [[NSUserDefaults standardUserDefaults] setObject:loc forKey:@"lastLocation"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
*/

- (void)requestStartDialog:(NSNotificationCenter*)notification
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"navcogdialog://start_dialog/?"]
                                       options:@{}
                             completionHandler:^(BOOL success) {
                                 if (!success) {
                                     UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Dialog App"
                                                                                                    message:@"You need to install NavCog dialog app"
                                                                                             preferredStyle:UIAlertControllerStyleAlert];
                                     [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK", @"BlindView", @"")
                                                                               style:UIAlertActionStyleDefault handler:nil]];
                                     
                                     UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
                                     while (topController.presentedViewController) {
                                         topController = topController.presentedViewController;
                                     }
                                     [topController presentViewController:alert animated:YES completion:nil];
                                 }
                             }];
}

- (void)requestShowRoute:(NSNotification*)note
{
    NSArray *route = [note userInfo][@"route"];
    [self showRoute:route];
}


- (void)retry
{
    [self loadUIPage];
}

- (HLPLocation *)getCenter
{
    NSString *script = @"(function(){var a=$hulop.map.getCenter();var f=$hulop.indoor.getCurrentFloor();f=f>0?f-1:f;return JSON.stringify({lat:a[1],lng:a[0],floor:f});})()";
    NSString *state = [self evalScript:script];
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[state dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (json) {
        return [[HLPLocation alloc] initWithLat:[json[@"lat"] doubleValue]
                                            Lng:[json[@"lng"] doubleValue]
                                          Floor:[json[@"floor"] doubleValue]];
    } else {
        NSLog(@"%@", error.localizedDescription);
    }
    return nil;
    
}

- (NSDictionary*) getState
{
    NSString *state = [self evalScript:@"(function(){return JSON.stringify($hulop.map.getState());})()"];
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[state dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (json) {
        return json;
    } else {
        NSLog(@"%@", error.localizedDescription);
    }
    return nil;
}

@end
