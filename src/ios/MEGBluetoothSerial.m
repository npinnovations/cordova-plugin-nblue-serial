
#if !TARGET_IPHONE_SIMULATOR
//
//  MEGBluetoothSerial.m
//  Bluetooth Serial Cordova Plugin
//
//  Created by Don Coleman on 5/21/13.
//
//

#import "MEGBluetoothSerial.h"
#import <Cordova/CDV.h>

@interface MEGBluetoothSerial()
- (NSString *)readUntilDelimiter:(NSString *)delimiter;
- (NSMutableArray *)getPeripheralList;
- (void)sendDataToSubscriber;
- (CBPeripheral *)findPeripheralByUUID:(NSString *)uuid;
- (void)connectToUUID:(NSString *)uuid;
- (void)listPeripheralsTimer:(NSTimer *)timer;
- (void)connectFirstDeviceTimer:(NSTimer *)timer;
- (void)connectUuidTimer:(NSTimer *)timer;
@end

@implementation MEGBluetoothSerial

- (void)pluginInitialize {
    
    //NSLog(@"Bluetooth Serial Cordova Plugin - BLE version");
    //NSLog(@"(c)2013 Don Coleman");
    
    [super pluginInitialize];
    _bleShield = [[BLE alloc] init];
    [_bleShield controlSetup];
    [_bleShield setDelegate:self];
    //[_brspShield setDelegate:self];
    
    _buffer = [[NSMutableString alloc] init];
}

#pragma mark - Cordova Plugin Methods

- (void)connect:(CDVInvokedUrlCommand *)command {
    
    NSLog(@"connect");
    CDVPluginResult *pluginResult = nil;
    NSString *uuid = [command.arguments objectAtIndex:0];
    NSLog(@"This is the command: %@",command);
    // if the uuid is null or blank, scan and
    // connect to the first available device
    
    if (uuid == (NSString*)[NSNull null]) {
        NSLog(@"This is what runs 1");
        [self connectToFirstDevice];
    } else if ([uuid isEqualToString:@""]) {
        NSLog(@"This is what runs 2");
        [self connectToFirstDevice];
    } else {
        NSLog(@"This is what runs 3");
        [self connectToUUID:uuid];
    }
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    NSLog(@"Plugin Result = %@",pluginResult);
    [pluginResult setKeepCallbackAsBool:TRUE];
    _connectCallbackId = [command.callbackId copy];
    NSLog(@"Connect Callback ID = %@",_connectCallbackId);
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)disconnect:(CDVInvokedUrlCommand*)command {
    
    NSLog(@"disconnect");
    
    CDVPluginResult *pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    
    if (_bleShield.activePeripheral) {
        if(_bleShield.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[_bleShield CM] cancelPeripheralConnection:[_bleShield activePeripheral]];
            return;
        }
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    _connectCallbackId = nil;
}

- (void)brsp:(Brsp*)brsp OpenStatusChanged:(BOOL)isOpen {
    // We can add code here for when Brsp open status has changed and is either open or not
    
}//Brsp

- (void)brsp:(Brsp*)brsp SendingStatusChanged:(BOOL)isSending {
    // We can add code here for when Brsp sending status has changed and is either sending or not
}//Brsp

- (void)subscribe:(CDVInvokedUrlCommand*)command {
    NSLog(@"subscribe");
    
    CDVPluginResult *pluginResult = nil;
    NSString *delimiter = [command.arguments objectAtIndex:0];
    //NSLog(@"%@", delimiter);
    
    if (delimiter != nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
        NSLog(@"Subscribe Plugin Result: %@",pluginResult);
        [pluginResult setKeepCallbackAsBool:TRUE];
        NSLog(@"%@",command.callbackId);
        _subscribeCallbackId = [command.callbackId copy];
        _delimiter = [delimiter copy];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"delimiter was null"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)write:(CDVInvokedUrlCommand*)command {
    // NSLog(@"write");
    
    CDVPluginResult *pluginResult = nil;
    NSString *message = [command.arguments objectAtIndex:0];
    
    if (message != nil) {
        
        // NSData *d = [message dataUsingEncoding:NSUTF8StringEncoding];
        //NSLog(@"%@",d);
        [_bleShield write:message];
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"message was null"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)list:(CDVInvokedUrlCommand*)command {
    
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:TRUE];
    
    [self scanForBLEPeripherals:3];
    
    [NSTimer scheduledTimerWithTimeInterval:(float)3.0
                                     target:self
                                   selector:@selector(listPeripheralsTimer:)
                                   userInfo:[command.callbackId copy]
                                    repeats:NO];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)isEnabled:(CDVInvokedUrlCommand*)command {
    
    // short delay so CBCentralManger can spin up bluetooth
    [NSTimer scheduledTimerWithTimeInterval:(float)0.2
                                     target:self
                                   selector:@selector(bluetoothStateTimer:)
                                   userInfo:[command.callbackId copy]
                                    repeats:NO];
    
    CDVPluginResult *pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)isConnected:(CDVInvokedUrlCommand*)command {
    
    CDVPluginResult *pluginResult = nil;
    
    if (_bleShield.isConnected) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not connected"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)available:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:[_buffer length]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)read:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;
    NSString *message = @"";
    //NSLog(@"I'm using READ");
    if ([_buffer length] > 0) {
        NSInteger end = [_buffer length] - 1;
        message = [_buffer substringToIndex:end];
        //NSLog(@"%@",message);
        NSRange entireString = NSMakeRange(0, end);
        [_buffer deleteCharactersInRange:entireString];
    }
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    NSLog(@"Read CallbackID: %@",command.callbackId);
    NSLog(@"Read Plugin Result: %@", pluginResult);
}

- (void)readUntil:(CDVInvokedUrlCommand*)command {
    NSLog(@"I'm using READUNTIL");
    NSString *delimiter = [command.arguments objectAtIndex:0];
    NSString *message = [self readUntilDelimiter:delimiter];
    CDVPluginResult *pluginResult = nil;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    NSLog(@"Read Until CallbackID: %@",command.callbackId);
    NSLog(@"Read Until Plugin Result: %@", pluginResult);
}

- (void)clear:(CDVInvokedUrlCommand*)command {
    NSInteger end = [_buffer length] - 1;
    NSRange truncate = NSMakeRange(0, end);
    [_buffer deleteCharactersInRange:truncate];
}

#pragma mark - BLEDelegate

- (void)bleDidReceiveData:(NSString *)str {//(unsigned char *)data length:(int)length {
    //NSLog(@"bleDidReceiveData");
    
    // Append to the buffer
    //NSData *d = [NSData dataWithBytes:data length:length];
    NSString *s = str; //[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    //NSLog(@"Received %@", s);
    [_buffer appendString:s];
    //NSLog(@"Buffer %@",_buffer);
    //NSLog(@"bleDidReceiveData Subscribe CallbackID: %@",_subscribeCallbackId);
    if (_subscribeCallbackId) {
        [self sendDataToSubscriber];
    }
}

- (void)bleDidConnect {
    NSLog(@"bleDidConnect");
    CDVPluginResult *pluginResult = nil;
    
    if (_connectCallbackId) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [pluginResult setKeepCallbackAsBool:TRUE];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_connectCallbackId];
    }
}

- (void)bleDidDisconnect {
    // TODO is there anyway to figure out why we disconnected?
    NSLog(@"bleDidDisconnect");
    
    CDVPluginResult *pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Device connection was lost. The iManifold may be out of range or is powered off. Please check the status of the iManifold and reconnect."];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_connectCallbackId];
    
    _connectCallbackId = nil;
}

// TODO future versions should add callback for signal strength
- (void)bleDidUpdateRSSI:(NSNumber *)rssi {
}

#pragma mark - timers

-(void)listPeripheralsTimer:(NSTimer *)timer {
    NSString *callbackId = [timer userInfo];
    NSMutableArray *peripherals = [self getPeripheralList];
    
    CDVPluginResult *pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray: peripherals];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

-(void)connectFirstDeviceTimer:(NSTimer *)timer {
    
    if(_bleShield.peripherals.count > 0) {
        NSLog(@"Connecting");
        [_bleShield connectPeripheral:[_bleShield.peripherals objectAtIndex:0]];
    } else {
        NSString *error = @"An active iManifold was not found. Make sure your iManifold is within range of this device and powered on, then try connecting again.";
        NSLog(@"%@", error);
        CDVPluginResult *pluginResult;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_connectCallbackId];
    }
}

-(void)connectUuidTimer:(NSTimer *)timer {
    
    NSString *uuid = [timer userInfo];
    
    CBPeripheral *peripheral = [self findPeripheralByUUID:uuid];
    
    if (peripheral) {
        [_bleShield connectPeripheral:peripheral];
    } else {
        NSString *error = @"An active iManifold was not found. Make sure your iManifold is within range of this device and powered on, then try connecting again.";
        //NSLog(@"%@", error);
        CDVPluginResult *pluginResult;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_connectCallbackId];
    }
}

- (void)bluetoothStateTimer:(NSTimer *)timer {
    
    NSString *callbackId = [timer userInfo];
    CDVPluginResult *pluginResult = nil;
    
    int bluetoothState = [[_bleShield CM] state];
    
    BOOL enabled = bluetoothState == CBCentralManagerStatePoweredOn;
    
    if (enabled) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:bluetoothState];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

#pragma mark - internal implemetation

- (NSString*)readUntilDelimiter: (NSString*) delimiter {
    NSRange range = [_buffer rangeOfString: delimiter];
    NSString *message = @"";
    
    if (range.location != NSNotFound) {
        //int end = range.location + range.length;
        //int end = range.location;
        //NSLog(@"This is the END value: %d",end);
        //message = [_buffer substringToIndex:end];
        
        
        //int end = [_buffer length] - 1;
        //message = [_buffer substringToIndex:end];
        
        //NSRange entireString = NSMakeRange(0, end);
        //[_buffer deleteCharactersInRange:entireString];
        
        
        //NSRange truncate = NSMakeRange(0, end);
        //[_buffer deleteCharactersInRange:truncate];
        
        NSInteger end = range.location + range.length - 1;
        //NSLog(@"End value: %d", end);
        message = [_buffer substringToIndex:end];
        //_buffer = [NSMutableString stringWithFormat:@"%@", message];
        NSRange truncate = NSMakeRange(0, end);
        //NSLog(@"readUntil Delimeter Buffer: %@",_buffer);
        [_buffer deleteCharactersInRange:truncate];
        //_buffer = [NSMutableString stringWithFormat:@"%@", @""];
        // NSLog(@"readUntil Delimeter Message: %@",message);
        // NSLog(@"readUntil Delimeter Buffer: %@",_buffer);
        
        
    }
    return message;
}

- (NSMutableArray*) getPeripheralList {
    
    NSMutableArray *peripherals = [NSMutableArray array];
    
    for (int i = 0; i < _bleShield.peripherals.count; i++) {
        NSMutableDictionary *peripheral = [NSMutableDictionary dictionary];
        CBPeripheral *p = [_bleShield.peripherals objectAtIndex:i];
        
        NSString *uuid = p.identifier.UUIDString;
        [peripheral setObject: uuid forKey: @"uuid"];
        [peripheral setObject: uuid forKey: @"id"];
        
        
        NSString *name = [p name];
        if (!name) {
            name = [peripheral objectForKey:@"uuid"];
        }
        [peripheral setObject: name forKey: @"name"];
        [peripherals addObject:peripheral];
    }
    
    return peripherals;
}

// calls the JavaScript subscriber with data if we hit the _delimiter
- (void) sendDataToSubscriber {
    
    NSString *message = [self readUntilDelimiter:_delimiter];
    
    if ([message length] > 0) {
        CDVPluginResult *pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: message];
        [pluginResult setKeepCallbackAsBool:TRUE];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_subscribeCallbackId];
    }
    
}

// Ideally we'd get a callback when found, maybe _bleShield can be modified
// to callback on centralManager:didRetrievePeripherals. For now, use a timer.
- (void)scanForBLEPeripherals:(int)timeout {
    
    NSLog(@"Scanning for BLE Peripherals");
    
    // disconnect
    if (_bleShield.activePeripheral) {
        if(_bleShield.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[_bleShield CM] cancelPeripheralConnection:[_bleShield activePeripheral]];
            return;
        }
    }
    
    // remove existing peripherals
    if (_bleShield.peripherals) {
        _bleShield.peripherals = nil;
    }
    
    [_bleShield findBLEPeripherals:timeout];
}

- (void)connectToFirstDevice {
    
    [self scanForBLEPeripherals:3];
    
    [NSTimer scheduledTimerWithTimeInterval:(float)3.0
                                     target:self
                                   selector:@selector(connectFirstDeviceTimer:)
                                   userInfo:nil
                                    repeats:NO];
}

- (void)connectToUUID:(NSString *)uuid {
    
    int interval = 0;
    
    if (_bleShield.peripherals.count < 1) {
        interval = 3;
        [self scanForBLEPeripherals:interval];
    }
    
    [NSTimer scheduledTimerWithTimeInterval:interval
                                     target:self
                                   selector:@selector(connectUuidTimer:)
                                   userInfo:uuid
                                    repeats:NO];
}

- (CBPeripheral*)findPeripheralByUUID:(NSString*)uuid {
    
    NSMutableArray *peripherals = [_bleShield peripherals];
    CBPeripheral *peripheral = nil;
    
    for (CBPeripheral *p in peripherals) {
        
        NSString *other = p.identifier.UUIDString;
        
        if ([uuid isEqualToString:other]) {
            peripheral = p;
            break;
        }
    }
    return peripheral;
}

@end
#endif