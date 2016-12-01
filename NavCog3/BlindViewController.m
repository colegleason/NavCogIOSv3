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

#import "BlindViewController.h"

#import "NavDeviceTTS.h"
#import "NavSound.h"

#import "LocationEvent.h"
#import "NavDataStore.h"
#import "NavUtil.h"

@import JavaScriptCore;
@import CoreMotion;


@interface BlindViewController () {
    NavWebviewHelper *helper;
    NavNavigator *navigator;
    NavCommander *commander;
    NavPreviewer *previewer;
    
    NSTimer *timerForSimulator;
    
    CMMotionManager *motionManager;
    NSOperationQueue *motionQueue;
    double yaws[10];
    int yawsIndex;
    double accs[10];
    int accsIndex;
    
    double turnAction;
    BOOL forwardAction;
    
    BOOL initFlag;
}

@end

@implementation BlindViewController

- (void)dealloc
{
    [helper prepareForDealloc];
    helper.delegate = nil;
    helper = nil;
    
    [navigator stop];
    navigator.delegate = nil;
    navigator = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    helper = [[NavWebviewHelper alloc] initWithWebview:self.webView];
    helper.delegate = self;
    
    navigator = [[NavNavigator alloc] init];
    commander = [[NavCommander alloc] init];
    previewer = [[NavPreviewer alloc] init];
    navigator.delegate = self;
    commander.delegate = self;
    previewer.delegate = self;    
    
    self.searchButton.enabled = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logReplay:) name:REQUEST_LOG_REPLAY object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationStatusChanged:) name:NAV_LOCATION_STATUS_CHANGE object:nil];
    
    UILongPressGestureRecognizer* longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];
    longPressGesture.minimumPressDuration = 1.0;
    longPressGesture.numberOfTouchesRequired = 1;
    [self.navigationController.navigationBar setUserInteractionEnabled:YES];
    [self.navigationController.navigationBar addGestureRecognizer:longPressGesture];
    UILongPressGestureRecognizer* longPressGesture2 = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];
    longPressGesture2.minimumPressDuration = 1.0;
    longPressGesture2.numberOfTouchesRequired = 2;
    [self.navigationController.navigationBar addGestureRecognizer:longPressGesture2];
    /*
    //In order to enable detection of gestures, but also panning and zomming the map when necessary
    UITapGestureRecognizer* doubleTapNav = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleEnableGestures:)];
    doubleTapNav.numberOfTapsRequired=2;
    [self.navigationController.navigationBar addGestureRecognizer:doubleTapNav];
    
    UISwipeGestureRecognizer * swipeLeft=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(swipeLeft:)];
    swipeLeft.direction=UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeLeft];
    
    UISwipeGestureRecognizer * swipeRight=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(swipeRight:)];
    swipeRight.direction=UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];
    
    UISwipeGestureRecognizer * swipeFront=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(swipeFront:)];
    swipeFront.direction=UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:swipeFront];
    
    UISwipeGestureRecognizer * swipeBack=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(swipeBack:)];
    swipeBack.direction=UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipeBack];
    
    UITapGestureRecognizer * doubleTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTap:)];
    doubleTap.numberOfTapsRequired=2;
    [self.view addGestureRecognizer:doubleTap];
    
    UILongPressGestureRecognizer * longPress=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longPress:)];
    longPress.minimumPressDuration=1;
    [self.view addGestureRecognizer:longPress];
     */
    
    [self locationChanged:nil];
}


//jpvg start
-(void)swipeLeft:(UISwipeGestureRecognizer*)gestureRecognizer
{
    [[NavSound sharedInstance] playSuccess];
}


-(void)swipeRight:(UISwipeGestureRecognizer*)gestureRecognizer
{
    [[NavSound sharedInstance] playSuccess];
}

-(void)swipeFront:(UISwipeGestureRecognizer*)gestureRecognizer
{
    [[NavSound sharedInstance] playSuccess];
}

-(void)swipeBack:(UISwipeGestureRecognizer*)gestureRecognizer
{
    [[NavSound sharedInstance] playSuccess];
}

-(void)doubleTap:(UITapGestureRecognizer*)gestureRecognizer
{
    [[NavSound sharedInstance] playSuccess];
}

-(void)toggleEnableGestures:(UITapGestureRecognizer*)gestureRecognizer
{
    [self.webView setUserInteractionEnabled:![self.webView isUserInteractionEnabled]];
}

-(void)longPress:(UILongPressGestureRecognizer*)gestureRecognizer
{
    [[NavSound sharedInstance] playSuccess];
}

- (void)handleLongPressGesture:(UILongPressGestureRecognizer*)sender
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"use_compass"]) {
        return;
    }
        
    if (sender.state == UIGestureRecognizerStateBegan &&
        ((UIAccessibilityIsVoiceOverRunning() == YES && sender.numberOfTouches == 1) ||
        sender.numberOfTouches == 2)) {
        initFlag = !initFlag;
        if (initFlag) {
            [[NSNotificationCenter defaultCenter] postNotificationName:START_ORIENTATION_INIT object:nil];
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            [NavUtil showWaitingForView:self.view withMessage:NSLocalizedStringFromTable(@"Init Orientation", @"BlindView", @"")];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:STOP_ORIENTATION_INIT object:nil];
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            [NavUtil hideWaitingForView:self.view];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [self updateView];
}

- (void) updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.searchButton.title = NSLocalizedStringFromTable([navigator isActive]?@"Stop":@"Search", @"BlindView", @"");
        [self.searchButton setAccessibilityLabel:NSLocalizedStringFromTable([navigator isActive]?@"Stop Navigation":@"Search Route", @"BlindView", @"")];
        
        BOOL devMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"];
        BOOL previewMode = [NavDataStore sharedDataStore].previewMode;
        BOOL isActive = [navigator isActive];

        self.devGo.hidden = !devMode || previewMode;
        self.devLeft.hidden = !devMode || previewMode;
        self.devRight.hidden = !devMode || previewMode;
        self.devAuto.hidden = !devMode || previewMode || !isActive;
        self.devReset.hidden = !devMode || previewMode;
        self.devMarker.hidden = !devMode || previewMode;
        
        self.devUp.hidden = !devMode || previewMode;
        self.devDown.hidden = !devMode || previewMode;
        self.devNote.hidden = !devMode || previewMode;
        self.devRestart.hidden = !devMode || previewMode;
        
        self.devAuto.selected = previewer.autoProceed;
        self.cover.hidden = devMode || !isActive;
        
        self.navigationItem.title = NSLocalizedStringFromTable(previewMode?@"Preview":@"NavCog", @"BlindView", @"");
    });

}

- (void)locationChanged:(NSNotification*)notification
{
    if (!self.searchButton.enabled) {
        if ([[NavDataStore sharedDataStore] currentLocation]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.searchButton.enabled = YES;
            });
        }
    }
}

- (void) logReplay:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIMessageView *mv = [NavUtil showMessageView:self.view];
        
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:LOG_REPLAY_PROGRESS object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            long progress = [[note object][@"progress"] longValue];
            long total = [[note object][@"total"] longValue];
            NSDictionary *marker = [note object][@"marker"];
            double floor = [[note object][@"floor"] doubleValue];
            double difft = [[note object][@"difft"] doubleValue]/1000;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (marker) {
                    mv.message.text = [NSString stringWithFormat:@"Log %03.0f%%:%03.1fs (%d:%.2f)",
                                       (progress /(double)total)*100, difft, [marker[@"floor"] intValue], floor];
                } else {
                    mv.message.text = [NSString stringWithFormat:@"Log %03.0f%%", (progress /(double)total)*100];
                }
                NSLog(@"%@", mv.message.text);
            });
            
            if (progress == total) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NavUtil hideMessageView:self.view];
                });
                [[NSNotificationCenter defaultCenter] removeObserver:observer];
            }
        }];
        
        [mv.action addTarget:self action:@selector(actionPerformed) forControlEvents:UIControlEventTouchDown];
    });
}

- (void)locationStatusChanged:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NavLocationStatus status = [[note object][@"status"] unsignedIntegerValue];
        
        switch(status) {
            case NavLocationStatusLocating:
                [NavUtil showWaitingForView:self.view withMessage:NSLocalizedStringFromTable(@"Locating...", @"BlindView", @"")];
                break;
            default:
                [NavUtil hideWaitingForView:self.view];
        }        
    });
}

- (void) actionPerformed
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOG_REPLAY_STOP object:nil];
}


- (void) startLoading {
    [_indicator startAnimating];
    _indicator.hidden = NO;
}

- (void) loaded {
    [_indicator stopAnimating];
    _indicator.hidden = YES;
}

- (void)checkConnection {
    [_indicator stopAnimating];
    _indicator.hidden = YES;
    _retryButton.hidden = NO;
    _errorMessage.hidden = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBActions

- (IBAction)turnLeftBit:(id)sender
{
    [previewer manualTurn:-10];
}

- (IBAction)turnRightBit:(id)sender {
    [previewer manualTurn:10];
}

- (IBAction)goForwardBit:(id)sender {
    [previewer manualGoForward:0.5];
}

- (IBAction)floorUp:(id)sender {
    double floor = [[[NavDataStore sharedDataStore] currentLocation] floor];
    
    [previewer manualGoFloor:floor+1];
}

- (IBAction)floorDown:(id)sender {
    double floor = [[[NavDataStore sharedDataStore] currentLocation] floor];
    [previewer manualGoFloor:floor-1];
}

- (IBAction)addNote:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Add Note"
                                                                   message:@"Input note for log"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
    }];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"BlindView", @"")
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK", @"BlindView", @"")
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                  NSLog(@"Note,%@,%ld",[[alert.textFields objectAtIndex:0]text],(long)([[NSDate date] timeIntervalSince1970]*1000));
                                              }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)resetLocation:(id)sender {
    HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_HEADING_RESET object:
     @{
       @"location":loc,
       @"heading":@(loc.orientation)
       }];
}

- (IBAction)makeMarker:(id)sender {
    HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
    long timestamp = (long)([[NSDate date] timeIntervalSince1970]*1000);
    NSLog(@"Marker,%f,%f,%f,%ld",loc.lat,loc.lng,loc.floor,timestamp);
}

- (IBAction)restartLocalization:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESTART object:nil];
}

- (IBAction)retry:(id)sender {
    [helper retry];
    _retryButton.hidden = YES;
    _errorMessage.hidden = YES;
}


- (IBAction)autoProceed:(id)sender {
    [previewer setAutoProceed:!previewer.autoProceed];
    [self updateView];
}

- (double)turnAction
{
    return turnAction;
}

- (BOOL)forwardAction
{
    return forwardAction;
}

- (void)stopAction
{
    [motionManager stopDeviceMotionUpdates];    
}

- (void)startAction
{
    BOOL needAction = [[NSUserDefaults standardUserDefaults] boolForKey:@"preview_with_action"];
    if (!motionManager && needAction) {
        motionManager = [[CMMotionManager alloc] init];
        motionManager.deviceMotionUpdateInterval = 0.01; //jpvg changed 0.1 to 0.01
        motionQueue = [[NSOperationQueue alloc] init];
        motionQueue.maxConcurrentOperationCount = 1;
        motionQueue.qualityOfService = NSQualityOfServiceBackground;
    }
    if (needAction) {
        [motionManager startDeviceMotionUpdatesToQueue:motionQueue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            
            //jpvg reusing previous turning functions
            yaws[yawsIndex] = motion.attitude.yaw;
            yawsIndex = (yawsIndex+1)%10;
            double ave = 0;
            for(int i = 0; i < 10; i++) {
                ave += yaws[i]*0.1;
            }
            //NSLog(@"angle=, %f, %f, %f", ave, motion.attitude.yaw, fabs(ave - motion.attitude.yaw));
            if (fabs(ave - motion.attitude.yaw) > M_PI*10/180) {
                turnAction = ave - motion.attitude.yaw;
            } else {
                turnAction = 0;
            }
            
            [previewer setPitch:motion.attitude.pitch withTurnAction:turnAction];
            
            //The Assessment of whether to trigger or not to trigger a step is done on the previewer
         
            /*
            CMAcceleration acc =  motion.userAcceleration;
            double d = sqrt(pow(acc.x, 2)+pow(acc.y, 2)+pow(acc.z, 2));
            accs[accsIndex] = d;
            accsIndex = (accsIndex+1)%10;
            ave = 0;
            for(int i = 0; i < 10; i++) {
                ave += accs[i]*0.1;
            }
            //NSLog(@"angle=, %f", ave);
            forwardAction = ave > 0.3;
             
             */
            
        }];
        
    }
}

#pragma mark - DialogViewControllerDelegate

- (void)startNavigationWithOptions:(NSDictionary *)options
{
    NSString *hash = [NSString stringWithFormat:@"navigate=%@&elv=%d&stairs=%d", options[@"node_id"], [options[@"no_elevator"] boolValue]?1:9, [options[@"no_stairs"] boolValue]?1:9];
    
    [helper setBrowserHash: hash];
}

- (NSString *)getCurrentFloor
{
    return [helper evalScript:@"(function() {return $hulop.indoor.getCurrentFloor();})()"];
}

#pragma mark - NavNavigator actions

- (IBAction)repeatLastSpokenAction:(id)sender
{
    
}

// tricky information in NavCog
// If there is any accessibility information the user is notified
// The user can access the information by executing this command
- (IBAction)speakAccessibilityInfo:(id)sender
{
    
}

// speak surroungind information
//  - link info for source node
//  - transit info
- (IBAction)speakSurroundingPOI:(id)sender
{
    
}

- (IBAction)stopNavigation:(id)sender
{
    
}

#pragma mark - NavNavigatorDelegate

- (void)didActiveStatusChanged:(NSDictionary *)properties
{
    [commander didActiveStatusChanged:properties];
    [previewer didActiveStatusChanged:properties];
    
    BOOL isActive = [properties[@"isActive"] boolValue];
    BOOL requestBackground = isActive && ![NavDataStore sharedDataStore].previewMode;
    if (!requestBackground) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_BACKGROUND_LOCATION object:@(requestBackground)];
    if ([properties[@"isActive"] boolValue]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [helper evalScript:@"$hulop.map.setSync(true);"];
            
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"reset_as_start_point"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESET object:properties];
//                
//                // if there is no location manager response
//                timerForSimulator = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer * _Nonnull timer) {
//                    [previewer manualGoFloor: [properties[@"location"] floor]];
//                    [previewer manualGoForward:0];
//                }];
            }
            
            [NavUtil showWaitingForView:self.view withMessage:NSLocalizedString(@"Loading, please wait",@"")];
            
            if ([NavDataStore sharedDataStore].previewMode) {
                [[NavDataStore sharedDataStore] manualLocationReset:properties];
                
                double delayInSeconds = 2.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [previewer setAutoProceed:YES];
                });
            }
        });
    } else {
        [previewer setAutoProceed:NO];
    }
    [self updateView];
}

- (void)couldNotStartNavigation:(NSDictionary *)properties
{
    [commander couldNotStartNavigation:properties];
    [previewer couldNotStartNavigation:properties];
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void)didNavigationStarted:(NSDictionary *)properties
{
    if (timerForSimulator) {
        [timerForSimulator invalidate];
        timerForSimulator = nil;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [helper evalScript:[NSString stringWithFormat:@"$hulop.map.getMap().setZoom(%f);", [[NSUserDefaults standardUserDefaults] doubleForKey:@"zoom_for_navigation"]]];
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideWaitingForView:self.view];
        NSArray *temp = [[NavDataStore sharedDataStore] route];
        //temp = [temp arrayByAddingObjectsFromArray:properties[@"oneHopLinks"]];
        [helper showRoute:temp];
    });
    
    [commander didNavigationStarted:properties];
    [previewer didNavigationStarted:properties];
}

- (void)didNavigationFinished:(NSDictionary *)properties
{
    [commander didNavigationFinished:properties];
    [previewer didNavigationFinished:properties];
}

// basic functions
- (void)userNeedsToChangeHeading:(NSDictionary*)properties
{
    [commander userNeedsToChangeHeading:properties];
    [previewer userNeedsToChangeHeading:properties];
}
- (void)userAdjustedHeading:(NSDictionary*)properties
{
    [commander userAdjustedHeading:properties];
    [previewer userAdjustedHeading:properties];
}
- (void)remainingDistanceToTarget:(NSDictionary*)properties
{
    [commander remainingDistanceToTarget:properties];
    [previewer remainingDistanceToTarget:properties];
}
- (void)userIsApproachingToTarget:(NSDictionary*)properties
{
    [commander userIsApproachingToTarget:properties];
    [previewer userIsApproachingToTarget:properties];
}
- (void)userNeedsToTakeAction:(NSDictionary*)properties
{
    [commander userNeedsToTakeAction:properties];
    [previewer userNeedsToTakeAction:properties];
}
- (void)userNeedsToWalk:(NSDictionary*)properties
{
    [commander userNeedsToWalk:properties];
    [previewer userNeedsToWalk:properties];
}
- (void)userGetsOnElevator:(NSDictionary *)properties
{
    [commander userGetsOnElevator:properties];
    [previewer userGetsOnElevator:properties];
}

// advanced functions
- (void)userMaybeGoingBackward:(NSDictionary*)properties
{
    [commander userMaybeGoingBackward:properties];
    [previewer userMaybeGoingBackward:properties];
}
- (void)userMaybeOffRoute:(NSDictionary*)properties
{
    [commander userMaybeOffRoute:properties];
    [previewer userMaybeOffRoute:properties];
}
- (void)userMayGetBackOnRoute:(NSDictionary*)properties
{
    [commander userMayGetBackOnRoute:properties];
    [previewer userMayGetBackOnRoute:properties];
}
- (void)userShouldAdjustBearing:(NSDictionary*)properties
{
    [commander userShouldAdjustBearing:properties];
    [previewer userShouldAdjustBearing:properties];
}

// POI
- (void)userIsApproachingToPOI:(NSDictionary*)properties
{
    [commander userIsApproachingToPOI:properties];
    [previewer userIsApproachingToPOI:properties];
}
- (void)userIsLeavingFromPOI:(NSDictionary*)properties
{
    [commander userIsLeavingFromPOI:properties];
    [previewer userIsLeavingFromPOI:properties];
}

#pragma mark - NavCommanderDelegate

- (void)speak:(NSString *)text completionHandler:(void (^)())handler
{
    [[NavDeviceTTS sharedTTS] speak:text completionHandler:handler];
}

- (void)speak:(NSString *)text force:(BOOL)flag completionHandler:(void (^)())handler
{
    [[NavDeviceTTS sharedTTS] speak:text force:flag completionHandler:handler];
}

- (void)playSuccess
{
    [[NavSound sharedInstance] playSuccess];
}

- (void)vibrate
{
    [[NavSound sharedInstance] vibrate];
}

- (void)executeCommand:(NSString *)command
{    
    JSContext *ctx = [[JSContext alloc] init];
    ctx[@"speak"] = ^(NSString *message) {
        [self speak:message completionHandler:^{
        }];
    };
    ctx[@"openURL"] = ^(NSString *url, NSString *title, NSString *message) {
        if (!title || !message || !url) {
            if (url) {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                });
            }
            return;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"BlindView", @"")
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                  }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK", @"BlindView", @"")
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                      dispatch_async(dispatch_get_main_queue(), ^(void){
                                                          [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                                                      });
                                                  }]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:alert animated:YES completion:nil];
        });
    };
    ctx.exceptionHandler = ^(JSContext *ctx, JSValue *e) {
        NSLog(@"%@", e);
        NSLog(@"%@", [e toDictionary]);
    };
    [ctx evaluateScript:command];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    [segue destinationViewController].restorationIdentifier = segue.identifier;
}

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"show_search"] && [navigator isActive]) {
        [[NavDataStore sharedDataStore] clearRoute];
        [NavDataStore sharedDataStore].previewMode = NO;
        [previewer setAutoProceed:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            [NavUtil hideWaitingForView:self.view];
        });

        return NO;
    }
    
    return YES;
}


@end
