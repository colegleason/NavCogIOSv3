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


#import "NavDataStore.h"
#import "HLPDataUtil.h"
#import "HLPGeoJSON.h"
#import "LocationEvent.h"
#import "Logging.h"

@implementation NavDestination {
    HLPLocation *_location;
}

- (BOOL) isEqual:(NavDestination*)obj
{
    if (_type != obj.type) {
        return NO;
    }
    
    switch(_type) {
        case NavDestinationTypeLandmark:
            return [_landmark isEqual:obj->_landmark];
        case NavDestinationTypeLocation:
            return [_location isEqual:obj->_location];
        default:
            break;
    }
    return NO;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[NSNumber numberWithInt:_type] forKey:@"type"];
    HLPLocation *loc;
    switch(_type) {
        case NavDestinationTypeLandmarks:
            [aCoder encodeObject:_landmarks forKey:@"landmarks"];
        case NavDestinationTypeLandmark:
            [aCoder encodeObject:_landmark forKey:@"landmark"];
            break;
        case NavDestinationTypeLocation:
            if (_location == nil) {
                loc = [[NavDataStore sharedDataStore] mapCenter];
            } else {
                loc = _location;
            }
            [aCoder encodeObject:loc forKey:@"location"];
            break;
        default:
            break;
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    _type = [[aDecoder decodeObjectForKey:@"type"] intValue];
    switch(_type) {
        case NavDestinationTypeLandmarks:
            _landmarks = [aDecoder decodeObjectForKey:@"landmarks"];
        case NavDestinationTypeLandmark:
            _landmark = [aDecoder decodeObjectForKey:@"landmark"];
            break;
        case NavDestinationTypeLocation:
            _location = [aDecoder decodeObjectForKey:@"location"];
            break;
        default:
            break;
    }
    return self;
}

- (instancetype)initWithLocation:(HLPLocation *)location
{
    self = [super init];
    _type = NavDestinationTypeLocation;
    _location = location;
    return self;
}

- (instancetype)initWithLandmark:(HLPLandmark *)landmark
{
    self = [super init];
    _type = NavDestinationTypeLandmark;
    _landmark = landmark;
    return self;
}

- (instancetype)initWithLabel:(NSString*)label Filter:(NSDictionary *)filter
{
    self = [super init];
    _type = NavDestinationTypeFilter;
    _label = label;
    _filter = filter;
    return self;
}
-(void)addLandmark:(HLPLandmark *)landmark
{
    if (!_landmarks) {
        _landmarks = @[_landmark];
        _type = NavDestinationTypeLandmarks;
    }
    _landmarks = [_landmarks arrayByAddingObject:landmark];
}

+ (instancetype)selectStart
{
    NavDestination *ret = [[NavDestination alloc] init];
    ret->_type = NavDestinationTypeSelectStart;
    return ret;
}

+ (instancetype)selectDestination
{
    NavDestination *ret = [[NavDestination alloc] init];
    ret->_type = NavDestinationTypeSelectDestination;
    return ret;
}

+ (instancetype)dialogSearch
{
    NavDestination *ret = [[NavDestination alloc] init];
    ret->_type = NavDestinationTypeDialogSearch;
    return ret;
}

- (NSString*)_id
{
    HLPLocation *loc;
    int floor;
    NSMutableString* __block temp = [@"" mutableCopy];
    switch(_type) {
        case NavDestinationTypeLandmark:
            return [_landmark nodeID];
        case NavDestinationTypeLandmarks:
            for(HLPLandmark *l in _landmarks) {
                if ([temp length] > 0) {
                    [temp appendString:@"|"];
                }
                [temp appendString:[l nodeID]];
            }
            return temp;
        case NavDestinationTypeLocation:
            if (_location == nil) {
                loc = [[NavDataStore sharedDataStore] mapCenter];
            } else {
                loc = _location;
            }
            floor = (int)round(loc.floor);
            floor = (floor >= 0)?floor+1:floor;
            return [NSString stringWithFormat:@"latlng:%f:%f:%d", loc.lat, loc.lng, floor];
        default:
            return nil;
    }
}


- (NSString*)singleId
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    if (_type == NavDestinationTypeLandmarks) {
        NavDestination *dest = [nds closestDestinationInLandmarks:_landmarks];
        return dest._id;
    }
    return self._id;
}

- (NSString*)name
{
    HLPLocation *loc;
    int floor;
    switch(_type) {
        case NavDestinationTypeLandmark:
        case NavDestinationTypeLandmarks:
            return [_landmark getLandmarkName];
        case NavDestinationTypeLocation:
            if (_location == nil) {
                loc = [[NavDataStore sharedDataStore] mapCenter];
                floor = (int)round(loc.floor);
                floor = (floor >= 0)?floor+1:floor;
                return [NSString stringWithFormat:@"%@(%f,%f,%@%dF)",
                        NSLocalizedStringFromTable(@"_nav_latlng", @"BlindView", @""),loc.lat,loc.lng,floor<0?@"B":@"",abs(floor)];
            } else {
                loc = _location;
                floor = (int)round(loc.floor);
                floor = (floor >= 0)?floor+1:floor;
                return [NSString stringWithFormat:@"%@(%f,%f,%@%dF)",
                        NSLocalizedStringFromTable(@"_nav_latlng_fix", @"BlindView", @""),loc.lat,loc.lng,floor<0?@"B":@"",abs(floor)];
            }
        case NavDestinationTypeSelectStart:
            return NSLocalizedStringFromTable(@"_nav_select_start", @"BlindView", @"");
        case NavDestinationTypeSelectDestination:
            return NSLocalizedStringFromTable(@"_nav_select_destination", @"BlindView", @"");
        case NavDestinationTypeFilter:
            return _label;
        case NavDestinationTypeDialogSearch:
            return NSLocalizedStringFromTable(@"DialogSearch", @"BlindView", @"");
    }
    return nil;
}

- (NSString*)namePron
{
    switch(_type) {
        case NavDestinationTypeLandmark:
        case NavDestinationTypeLandmarks:
            return [_landmark getLandmarkNamePron];
        case NavDestinationTypeLocation:
            if (_location == nil) {
                return NSLocalizedStringFromTable(@"_nav_latlng", @"BlindView", @"");
            }
        default:
            return [self name];
    }
    return nil;
}
@end

@implementation NavDataStore {
    // location instance that keep the current status should be handled
    HLPLocation *location;
    
    // parameters passed from location manager and manual operations
    BOOL isManualLocation;
    HLPLocation *manualCurrentLocation;
    HLPLocation *currentLocation;
    HLPLocation *savedLocation;
    HLPLocation *savedCenterLocation;
    BOOL savedIsManualLocation;
    
    double magneticOrientation;
    double magneticOrientationAccuracy;
    BOOL _previewMode;
    
    double manualOrientation;
    
    // parameters for request
    NSString* _userID;
    NSString* userLanguage;
    
    // cached data
    NSArray* destinationCache;
    HLPLocation* destinationCacheLocation;
    
    BOOL destinationRequesting;
    NSArray* routeCache;
    NSArray* featuresCache;
    
    NSDictionary *destinationHash;
    NSDictionary *serverConfig;
}

static NavDataStore* instance_ = nil;

+ (instancetype)sharedDataStore{
    if (!instance_) {
        instance_ = [[NavDataStore alloc] init];
    }
    return instance_;
}

- (instancetype) init
{
    self = [super init];
    
    [self reset];
    
    userLanguage = [[[NSLocale preferredLanguages] objectAtIndex:0] substringToIndex:2];
    
    // prevent problem on server cache
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:LOCATION_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:ORIENTATION_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(manualLocationChanged:) name:MANUAL_LOCATION_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processShowRouteLog:) name:REQUEST_PROCESS_SHOW_ROUTE_LOG object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processInitTargetLog:) name:REQUEST_PROCESS_INIT_TARGET_LOG object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buildingChanged:) name:BUILDING_CHANGED_NOTIFICATION object:nil];

    return self;
}

- (void) setUserID:(NSString *)userID
{
    //_userID = [NSString stringWithFormat:@"%@:%@", userID, userLanguage];
    _userID = userID;
}

- (NSString*) userID
{
    return _userID;
}

- (void) reset
{
    isManualLocation = NO;
    destinationRequesting = NO;
    
    magneticOrientationAccuracy = 180;
    
    location = [[HLPLocation alloc] init];
    [location updateOrientation:0 withAccuracy:999];
    currentLocation = [[HLPLocation alloc] init];
    [currentLocation updateOrientation:0 withAccuracy:999];

    /*
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    if ([ud dictionaryForKey:@"lastLocation"]) {
        NSDictionary *dic = [ud dictionaryForKey:@"lastLocation"];
        double lat = [dic[@"lat"] doubleValue];
        double lng = [dic[@"lng"] doubleValue];
        double x = cos(lng/180*M_PI);
        double y = sin(lng/180*M_PI);
        lng = atan2(y,x)/M_PI*180;

        [currentLocation updateLat:lat Lng:lng Accuracy:0 Floor:0];
    }
     */
}


- (void) locationChanged: (NSNotification*) note
{
    if (_previewMode) {
        return;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"p2p_debug_follower"]) {
        return;
    }
    
    NSDictionary *obj = [note userInfo];
    
    currentLocation = [[HLPLocation alloc] initWithLat:[obj[@"lat"] doubleValue]
                                                   Lng:[obj[@"lng"] doubleValue]
                                              Accuracy:[obj[@"accuracy"] doubleValue]
                                                 Floor:[obj[@"floor"] doubleValue]
                                                 Speed:[obj[@"speed"] doubleValue]
                                           Orientation:[obj[@"orientation"] doubleValue]
                                   OrientationAccuracy:[obj[@"orientationAccuracy"] doubleValue]];
        
    if (obj[@"debug_info"] || obj[@"debug_latlng"]) {
        [currentLocation updateParams:obj];
    }
    
    if (!isManualLocation) {
        [self postLocationNotification];
    }
}


-(void) postLocationNotification
{
    HLPLocation *loc = [self currentLocation];
    if (loc && [Logging isLogging]) {
        long now = (long)([[NSDate date] timeIntervalSince1970]*1000);
        NSLog(@"Pose,%f,%f,%f,%f,%f,%f,%ld",loc.lat,loc.lng,loc.floor,loc.accuracy,loc.orientation,loc.orientationAccuracy,now);
    }
    [[NSNotificationCenter defaultCenter]
     postNotificationName:NAV_LOCATION_CHANGED_NOTIFICATION
     object: self
     userInfo:
     @{
       @"current":loc?loc:[NSNull null],
       @"isManual":@(isManualLocation),
       
       // Removed nan check to publish unknown lat and lng
       //@"actual":(isnan(currentLocation.lat)||isnan(currentLocation.lng))?[NSNull null]:currentLocation
       @"actual":currentLocation
       }];
}

- (void) orientationChanged: (NSNotification*) note
{
    if (_previewMode) {
        return;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"p2p_debug_follower"]) {
        return;
    }

    NSDictionary *obj = [note userInfo];
    
    magneticOrientation = [obj[@"orientation"] doubleValue];
    magneticOrientationAccuracy = [obj[@"orientationAccuracy"] doubleValue];
    
    [self postLocationNotification];
}

- (void) manualLocationChanged: (NSNotification*) note
{
    NSDictionary *obj = [note userInfo];
    double floor = [obj[@"floor"] doubleValue];
    if (floor >= 1) {
        floor -= 1;
    }
    BOOL firstMapCenter = (_mapCenter == nil);
    _mapCenter = [[HLPLocation alloc] initWithLat:[obj[@"lat"] doubleValue]
                                             Lng:[obj[@"lng"] doubleValue]
                                        Accuracy:1
                                           Floor:floor
                                           Speed:1.0
                                     Orientation:0
                             OrientationAccuracy:999];
    if ([[note userInfo][@"sync"] boolValue]) {
        if (firstMapCenter) {
            [self postLocationNotification];
        }
        isManualLocation = NO;
        manualCurrentLocation = nil;
    } else {
        if (_previewMode) {
            return;
        }
        isManualLocation = YES;
        manualCurrentLocation = _mapCenter;
        [self postLocationNotification];
    }
}

- (HLPLocation*) currentLocation
{
    
    // Removed nan check
    //if (isnan(currentLocation.lat) && isnan(manualCurrentLocation.lat)) {
    //    return nil;
    //}
    
    [location update:currentLocation];
    
    if (manualCurrentLocation) {
        [location updateLat:manualCurrentLocation.lat
                        Lng:manualCurrentLocation.lng
                   Accuracy:manualCurrentLocation.accuracy
                      Floor:manualCurrentLocation.floor];
        [location updateSpeed:manualCurrentLocation.speed];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"]) {
            [location updateOrientation:manualOrientation
                           withAccuracy:0];
        } else {
            if (magneticOrientationAccuracy < location.orientationAccuracy) {
                [location updateOrientation:magneticOrientation
                               withAccuracy:magneticOrientationAccuracy];
            }
        }
    }
    
    // Removed orientation check
    //else {
    //    if (magneticOrientationAccuracy < location.orientationAccuracy) {
    //        [location updateOrientation:magneticOrientation
    //                       withAccuracy:magneticOrientationAccuracy];
    //    }
    //}
    
    // Removed nan check
    //if (isnan(location.lat) || isnan(location.lng)) {
    //    return nil;
    //}
    
    HLPLocation *newLoc = [[HLPLocation alloc] init];
    [newLoc update:location];
    return newLoc;
    
    //return location;
}

- (NSArray *)route
{
    return routeCache;
}

- (NSArray *)features
{
    return featuresCache;
}

- (void)processInitTargetLog:(NSNotification*)note
{
    NSString *logstr = [note userInfo][@"text"];
    NSRange r1 = [logstr rangeOfString:@","];
    NSString *s1 = [logstr substringFromIndex:r1.location+r1.length];
    NSRange r2 = [s1 rangeOfString:@","];
    NSString *s2 = [s1 substringFromIndex:r2.location+r2.length];
    
    NSDictionary *param = [NSJSONSerialization JSONObjectWithData:[s2 dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    double lat = [param[@"lat"] doubleValue];
    double lng = [param[@"lng"] doubleValue];
    NSString *user = param[@"user"];
    NSString *lang = param[@"user_lang"];
    [self reloadDestinationsAtLat:lat Lng:lng forUser:user withUserLang:lang];
}

- (void)processShowRouteLog:(NSNotification*)note
{
    NSString *logstr = [note userInfo][@"text"];
    NSRange r1 = [logstr rangeOfString:@","];
    NSString *s1 = [logstr substringFromIndex:r1.location+r1.length];
    NSRange r2 = [s1 rangeOfString:@","];
    NSString *s2 = [s1 substringFromIndex:r2.location+r2.length];
    
    NSDictionary *param = [NSJSONSerialization JSONObjectWithData:[s2 dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    NSString *fromID = param[@"fromID"];
    NSString *toID = param[@"toID"];
    NSString *user = param[@"user"];
    NSString *lang = param[@"user_lang"];
    NSDictionary *prefs = param[@"prefs"];
    [self requestRouteFrom:fromID To:toID forUser:user withLang:lang useCache:NO withPreferences:prefs complete:nil];
}


- (BOOL)reloadDestinations:(BOOL)force;
{
    if (destinationRequesting) {
        return NO;
    }
    if (force) {
        destinationCacheLocation = nil;
    }
    destinationRequesting = YES;
    double lat = [self mapCenter].lat;
    double lng = [self mapCenter].lng;
    
    NSString *user = [self userID];
    NSString *user_lang = [self userLanguage];
    
    return [self reloadDestinationsAtLat:lat Lng:lng forUser:user withUserLang:user_lang];
}

- (NSString*)normalizePron:(NSString*)str
{
    NSMutableString* retStr = [[NSMutableString alloc] initWithString:str];
    CFStringTransform((CFMutableStringRef)retStr, NULL, kCFStringTransformHiraganaKatakana, YES);
    return retStr;
}

- (BOOL)reloadDestinationsAtLat:(double)lat Lng:(double)lng forUser:(NSString*)user withUserLang:(NSString*)user_lang
{
    if (isnan(lat) || isnan(lng) || user == nil || user_lang == nil) {
        return NO;
    }
    int dist = 500;
    
    HLPLocation *requestLocation = [[HLPLocation alloc] initWithLat:lat Lng:lng];
    if (destinationCacheLocation && [destinationCacheLocation distanceTo:requestLocation] < dist/2) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DESTINATIONS_CHANGED_NOTIFICATION object:self userInfo:@{@"destinations":destinationCache?destinationCache:@[]}];
        });
        destinationRequesting = NO;
        return NO;
    }
    
    NSDictionary *param = @{@"lat":@(lat), @"lng":@(lng), @"user":user, @"user_lang":user_lang};
    [Logging logType:@"initTarget" withParam:param];
    
    [HLPDataUtil loadLandmarksAtLat:lat Lng:lng inDist:dist forUser:user withLang:user_lang withCallback:^(NSArray<HLPObject *> *result) {
        if (result == nil) {
            destinationRequesting = NO;
            destinationCache = nil;
            destinationCacheLocation = nil;
            destinationHash = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DESTINATIONS_CHANGED_NOTIFICATION object:self userInfo:@{@"destinations":destinationCache?destinationCache:@[]}];
            });
            return;
        }
        //NSLog(@"%ld landmarks are loaded", (unsigned long)[result count]);
        destinationCache = [result sortedArrayUsingComparator:^NSComparisonResult(HLPLandmark *obj1, HLPLandmark *obj2) {
            return [[self normalizePron:[obj1 getLandmarkNamePron]] compare:[self normalizePron:[obj2 getLandmarkNamePron]]];
        }];
        destinationCacheLocation = requestLocation;
                
        NSMutableDictionary *temp = [@{} mutableCopy];
        [destinationCache enumerateObjectsUsingBlock:^(HLPLandmark *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            temp[[obj nodeID]] = obj;
        }];
        destinationHash = temp;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DESTINATIONS_CHANGED_NOTIFICATION object:self userInfo:@{@"destinations":destinationCache?destinationCache:@[]}];
        });

        destinationRequesting = NO;
    }];
    return YES;
}

- (void) saveHistory
{
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* path = [documentsPath stringByAppendingPathComponent:@"history.object"];

    NSArray *history = @[];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        history = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    }
    
    NSDictionary *newHist = @{
                              @"from":[NSKeyedArchiver archivedDataWithRootObject:_from],
                              @"to":[NSKeyedArchiver archivedDataWithRootObject:_to]};
    
    
    if ([history count] > 0) {
        BOOL __block flag = YES;
        [newHist enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            
            NavDestination *dest1 = [NSKeyedUnarchiver unarchiveObjectWithData:[history firstObject][key]];
            NavDestination *dest2 = [NSKeyedUnarchiver unarchiveObjectWithData:obj];
            
            flag = flag && [dest1 isEqual:dest2];
        }];
        if (flag) {
            return;
        }
    }
    NSMutableArray *temp = [history mutableCopy];
    [temp insertObject:newHist
               atIndex:0];
    
    while([temp count] > 5) {
        [temp removeLastObject];
    }
    [NSKeyedArchiver archiveRootObject:temp toFile:path];
}

- (void)requestRouteFrom:(NSString *)fromID To:(NSString *)toID withPreferences:(NSDictionary *)prefs complete:(void (^)())complete
{
    [self saveHistory];
    [self requestRouteFrom:fromID To:toID forUser:self.userID withLang:self.userLanguage useCache:NO withPreferences:prefs complete:complete];
}

- (void)requestRerouteFrom:(NSString *)fromID To:(NSString *)toID withPreferences:(NSDictionary *)prefs complete:(void (^)())complete
{
    [self requestRouteFrom:fromID To:toID forUser:self.userID withLang:self.userLanguage useCache:YES withPreferences:prefs complete:complete];
}

- (void)requestRouteFrom:(NSString *)fromID To:(NSString *)toID forUser:(NSString*)user withLang:(NSString*)lang useCache:(BOOL)useCache withPreferences:(NSDictionary *)prefs complete:(void (^)())complete
{
    if (fromID == nil || toID == nil || user == nil || lang == nil || prefs == nil) {
        return;
    }
    NSDictionary *param = @{@"fromID":fromID, @"toID":toID, @"user":user, @"user_lang":lang, @"prefs":prefs};
    [Logging logType:@"showRoute" withParam:param];

    [HLPDataUtil loadRouteFromNode:fromID toNode:toID forUser:user withLang:lang withPrefs:prefs withCallback:^(NSArray<HLPObject *> *result) {
        routeCache = result;
        if (useCache && featuresCache) {
            if (complete) {
                complete();
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CHANGED_NOTIFICATION object:self userInfo:@{@"route":routeCache?routeCache:@[]}];
            return;
        }
        [HLPDataUtil loadNodeMapForUser:user withLang:lang WithCallback:^(NSArray<HLPObject *> *result) {
            featuresCache = result;
            [HLPDataUtil loadFeaturesForUser:user withLang:lang WithCallback:^(NSArray<HLPObject *> *result) {
                featuresCache = [featuresCache arrayByAddingObjectsFromArray: result];
                
                for(HLPObject* f in featuresCache) {
                    [f updateWithLang:lang];
                }
                
                if (complete) {
                    complete();
                }
                
                [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CHANGED_NOTIFICATION object:self userInfo:@{@"route":routeCache?routeCache:@[]}];
            }];
        }];
    }];
    
}

#define CONFIG_JSON @"%@://%@/%@config/dialog_config.json"

- (void)requestServerConfigWithComplete:(void(^)())complete
{
    NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:@"selected_hokoukukan_server"];
    
    if (!server || [server length] == 0) {
        return;
    }
    
    NSString *context = [[NSUserDefaults standardUserDefaults] stringForKey:@"hokoukukan_server_context"];
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:CONFIG_JSON, https, server, context]];

    [HLPDataUtil getJSON:url withCallback:^(NSObject* json){
        if (json && [json isKindOfClass:NSDictionary.class]) {
            serverConfig = (NSDictionary*)json;
            complete();
        } else {
            NSLog(@"error in loading dialog_config, retrying...");
            double delayInSeconds = 3.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self requestServerConfigWithComplete:complete];
            });
        }
    }];
}

- (NSDictionary*)serverConfig
{
    return serverConfig;
}

- (BOOL) isManualLocation
{
    return isManualLocation;
}

- (void)clearRoute
{
    routeCache = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CLEARED_NOTIFICATION object:self];
}

- (NSArray*)destinations
{
    return destinationCache;
}

- (NSString*) userLanguage
{
    return userLanguage;
}

- (NSArray*) searchHistory
{
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* path = [documentsPath stringByAppendingPathComponent:@"history.object"];
    
    NSArray *history = @[];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        history = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    }

    return history;
}

- (void)switchFromTo
{
    NavDestination *temp = _from;
    _from = _to;
    _to = temp;
}

- (NavDestination*)destinationByID:(NSString *)key
{
    return [[NavDestination alloc] initWithLandmark: [destinationHash objectForKey:key]];
}

- (NavDestination *)destinationByIDs:(NSArray *)keys
{
    NavDestination *dest = nil;
    for(NSString *key in keys) {
        HLPLandmark *l = [destinationHash objectForKey:key];
        if (dest == nil) {
            dest = [[NavDestination alloc] initWithLandmark:l];
        } else {
            [dest addLandmark:l];
        }
    }
    return dest;
}

- (NavDestination *)closestDestinationInLandmarks:(NSArray *)landmarks
{
    HLPLocation *loc = [self currentLocation];
    double min = DBL_MAX;
    HLPLandmark *minl = nil;
    for(HLPLandmark *l in landmarks) {
        if (l) {
            double d = [[l nodeLocation] distanceTo:loc];
            if (d < min) {
                min = d;
                minl = l;
            }
        }
    }
    return [[NavDestination alloc] initWithLandmark: minl];
}


- (void)manualTurn:(double)diffOrientation
{
    if (_previewMode) {
        [currentLocation updateOrientation:currentLocation.orientation+diffOrientation withAccuracy:-1];
        [self postLocationNotification];
    }
    else {
        manualOrientation += diffOrientation;
        magneticOrientationAccuracy = 0;
        [self postLocationNotification];
    }
}

- (void)manualLocation:(HLPLocation *)loc
{
    if (loc == nil) {
        [self postLocationNotification];
    }
    else {
        if (_previewMode) {
            [currentLocation updateLat:loc.lat Lng:loc.lng Accuracy:1.0 Floor:loc.floor];
            [self postLocationNotification];
        }
    }
}

- (void)manualLocationReset:(NSDictionary *)properties
{
    if (_previewMode) {
        HLPLocation *loc = properties[@"location"];
        [loc updateLat:loc.lat Lng:loc.lng Accuracy:1.5 Floor:loc.floor];
        double heading = [properties[@"heading"] doubleValue];
        heading = isnan(heading)?0:heading;
        manualOrientation = heading;
        [loc updateOrientation:heading withAccuracy:-1];
        [currentLocation update:loc];
        [self postLocationNotification];
    }
}

- (void)clearSearchHistory
{
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* path = [documentsPath stringByAppendingPathComponent:@"history.object"];

    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (BOOL)isKnownDestination:(NavDestination *)dest
{
    switch(dest.type) {
        case NavDestinationTypeLocation:
            return YES;
        case NavDestinationTypeLandmark:
        case NavDestinationTypeLandmarks:
            return [destinationHash objectForKey:dest.landmark.nodeID] != nil;
        default:
            return NO;
    }
}

+ (NavDestination*) destinationForCurrentLocation;
{
    return [[NavDestination alloc] initWithLocation:nil];
}

- (void)setPreviewMode:(BOOL)previewMode
{
    if (_previewMode != previewMode) {
        if (previewMode) {
            if (!savedLocation) {
                savedLocation = [[HLPLocation alloc] init];
                [savedLocation update:currentLocation];
                savedCenterLocation = [[HLPLocation alloc] init];
                [savedCenterLocation update:_mapCenter];
                savedIsManualLocation = isManualLocation;
            }
        } else {
            if (savedCenterLocation) {
                [_mapCenter update:savedCenterLocation];
                if (_mapCenter) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:MANUAL_LOCATION
                                                                        object:self
                                                                      userInfo:@{@"location":_mapCenter,
                                                                                 @"sync":@(!savedIsManualLocation)}];
                }
            }
            [currentLocation update:savedLocation];
            savedLocation = nil;
            [self postLocationNotification];
        }
    }
    _previewMode = previewMode;
}

- (BOOL)previewMode
{
    return _previewMode;
}

- (void)buildingChanged:(NSNotification*)note
{
    NSDictionary *dict = [note userInfo];
    _buildingInfo = dict;
}

- (void) startExercise
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"exercise-data" ofType:@"json"];
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        return;
    }
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    if (!json) {
        NSLog(@"not valid exercise data");
        return;
    }
    if (json[@"landmark"] && json[@"route"] && json[@"features"]) {
        HLPLandmark *landmark = [MTLJSONAdapter modelOfClass:HLPLandmark.class fromJSONDictionary:json[@"landmark"] error:&error];
        
        NSMutableArray *route = [@[] mutableCopy];
        for(NSDictionary* dic in json[@"route"]) {
            NSError *error;
            HLPObject *obj = [MTLJSONAdapter modelOfClass:HLPObject.class fromJSONDictionary:dic error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", dic);
            } else {
                [route addObject:obj];
            }
        }
        routeCache = route;
        
        NSMutableArray *features = [@[] mutableCopy];
        for(NSDictionary* dic in json[@"features"]) {
            NSError *error;
            HLPObject *obj = [MTLJSONAdapter modelOfClass:HLPObject.class fromJSONDictionary:dic error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", dic);
            } else {
                [features addObject:obj];
            }
        }
        featuresCache = features;
        
        for(HLPObject* f in featuresCache) {
            [f updateWithLang:userLanguage];
        }
        
        self.to = [[NavDestination alloc] initWithLandmark:landmark];
        self.previewMode = YES;
        self.exerciseMode = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CHANGED_NOTIFICATION object:self userInfo:@{@"route":route}];
    }
}

@end

