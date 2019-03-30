/********* GaoDeLocation.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import <AMapFoundationKit/AMapFoundationKit.h>

#import <AMapLocationKit/AMapLocationKit.h>
#include <math.h>
@interface GaoDeLocation : CDVPlugin {
    // Member variables go here.
    //圆周率 GCJ_02_To_WGS_84
    double PI ;
}

@property(nonatomic,strong)NSString *IOS_API_KEY;
@property (nonatomic, strong) AMapLocationManager *locationManager;
@property(nonatomic,strong)NSString *currentCallbackId;
- (void)getCurrentPosition:(CDVInvokedUrlCommand*)command;
@end

@implementation GaoDeLocation
-(void)pluginInitialize
{
    self.IOS_API_KEY = [[self.commandDelegate settings] objectForKey:@"ios_api_key"];
    PI= 3.14159265358979324;
    [AMapServices sharedServices].apiKey =self.IOS_API_KEY;
    // 带逆地理信息的一次定位（返回坐标和地址信息）
    [self configLocationManager];
    
}
- (void)getCurrentPosition:(CDVInvokedUrlCommand*)command
{
    self.currentCallbackId = command.callbackId;
    [self locateAction];
}

- (void)configLocationManager
{
    self.locationManager = [[AMapLocationManager alloc] init];
    
    [self.locationManager setDelegate: self];
    
    [self.locationManager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
    
    [self.locationManager setLocationTimeout:6];
    
    [self.locationManager setReGeocodeTimeout:3];
}

- (void)locateAction
{
    //带逆地理的单次定位
    [self.locationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
        
        if (error)
        {
            NSLog(@"locError:{%ld - %@};", (long)error.code, error.localizedDescription);
            
            if (error.code == AMapLocationErrorLocateFailed)
            {
                return;
            }
        }
        
        //定位信息
        NSLog(@"location:%@", location);
        
        //逆地理信息
        if (regeocode)
        {
            NSMutableDictionary *mDict = [[NSMutableDictionary alloc] init];
            //转成标准gps坐标
            NSDictionary *gpsDic=[self deltaWithLatAndLng:location.coordinate.latitude lon:location.coordinate.longitude];
            [mDict setObject:@"定位成功" forKey:@"status"];
            [mDict setObject:@"" forKey:@"type"];
            [mDict setObject:[gpsDic objectForKey:@"lat"] forKey:@"latitude"];
            [mDict setObject:[gpsDic objectForKey:@"lon"] forKey:@"longitude"];
            [mDict setObject:[NSString stringWithFormat:@"%g",location.horizontalAccuracy] forKey:@"accuracy"];
            //        [mDict setObject:[NSString stringWithFormat:@"%g",location.bearing] forKey:@"bearing"];
            //        [mDict setObject:@"one2" forKey:@"satellites"];
            [mDict setObject:regeocode.country forKey:@"country"];
            [mDict setObject:regeocode.province forKey:@"province"];
            [mDict setObject:regeocode.city forKey:@"city"];
            [mDict setObject:regeocode.citycode forKey:@"citycode"];
            [mDict setObject:regeocode.district forKey:@"district"];
            [mDict setObject:regeocode.adcode forKey:@"adcode"];
            [mDict setObject:regeocode.formattedAddress forKey:@"address"];
            [mDict setObject:regeocode.POIName forKey:@"poi"];
            //        [mDict setObject:
            //         location.timestamp
            //          forKey:@"time"];
            CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:mDict];
            [self.commandDelegate sendPluginResult:commandResult callbackId:self.currentCallbackId];
        }else{
            NSMutableDictionary *mDict = [[NSMutableDictionary alloc] init];
            [mDict  setObject:@"定位失败" forKey:@"status"];
            //            [mDict  setObject:location.timestamp forKey:@"errcode"]
            CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:mDict];
            [self.commandDelegate sendPluginResult:commandResult callbackId:self.currentCallbackId];
        }
    }];
}
- (void)successWithCallbackID:(NSString *)callbackID messageAsDictionary:(NSDictionary *)message
{
    NSLog(@"message = %@",message);
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}


/**
 * @author 作者:
 * 方法描述:方法可以将高德地图SDK获取到的GPS经纬度转换为真实的经纬度
 * @param 需要转换的经纬度
 * @return 转换为真实GPS坐标后的经纬度
 * @throws <异常类型> {@inheritDoc} 异常描述
 */
-(NSDictionary*) deltaWithLatAndLng:  (double) lat
                  lon: (double) lon {
    double a = 6378245.0;//克拉索夫斯基椭球参数长半轴a
    double ee = 0.00669342162296594323;//克拉索夫斯基椭球参数第一偏心率平方
    double dLat = [self transformLat:lon - 105.0 y: lat - 35.0];
    double dLon = [self transformLon:lon - 105.0 y:lat - 35.0 ];
    double radLat = lat / 180.0 * PI;
    double magic = sin(radLat);
    magic = 1 - ee * magic * magic;
    double sqrtMagic = sqrt(magic);
    dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * PI);
    dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * PI);
    NSDictionary *dic= [[NSDictionary alloc]initWithObjectsAndKeys:[NSNumber    numberWithDouble:lat - dLat] , @"lat",
                        [NSNumber numberWithDouble:lon - dLon] , @"lon",nil];

    
    return dic;
}
//转换经度
-(double) transformLon: (double) x
    y:(double) y {
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x));
    ret += (20.0 * sin(6.0 * x * PI) + 20.0 * sin(2.0 * x * PI)) * 2.0 / 3.0;
    ret += (20.0 * sin(x * PI) + 40.0 * sin(x / 3.0 * PI)) * 2.0 / 3.0;
    ret += (150.0 * sin(x / 12.0 * PI) + 300.0 * sin(x / 30.0 * PI)) * 2.0 / 3.0;
    return ret;
}
//转换纬度
-(double) transformLat: (double) x
                     y:(double) y {
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x));
    ret += (20.0 * sin(6.0 * x * PI) + 20.0 *sin(2.0 * x * PI)) * 2.0 / 3.0;
    ret += (20.0 * sin(y * PI) + 40.0 * sin(y / 3.0 * PI)) * 2.0 / 3.0;
    ret += (160.0 * sin(y / 12.0 * PI) + 320 * sin(y * PI / 30.0)) * 2.0 / 3.0;
    return ret;
}
@end
