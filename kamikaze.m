#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>

NSDictionary *_browserScripts;

double lastCheckTime;
double checkDelta = 1.0;

#define fatal(fmt, ...) do { fprintf(stderr, fmt, ## __VA_ARGS__); exit(1); } while(0);

NSDictionary *browserScripts() {
  NSString *safariScript = @"tell application \"Safari\"\n\treturn URL of front document as string\nend tell";
  NSString *chromeScript = @"tell application \"Google Chrome\"\n\treturn URL of active tab of window 1\nend tell";
  if(!_browserScripts) {
    _browserScripts = [[NSDictionary dictionaryWithObjects:
      [NSArray arrayWithObjects:
        [[NSAppleScript alloc] initWithSource:safariScript],
        [[NSAppleScript alloc] initWithSource:chromeScript], nil] 
      forKeys: [NSArray arrayWithObjects: @"Safari", @"Google Chrome", nil]] retain];
  }
  return _browserScripts;
}

NSString *currentHost(NSString *browser) {
  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  NSString *host = nil;
  
  if((now - lastCheckTime) > checkDelta) {      
    NSDictionary *err;
    NSAppleScript *script = [browserScripts() objectForKey: browser];
    NSAppleEventDescriptor *ret = [script executeAndReturnError:&err];
    NSString *url = [ret stringValue];
    if(url) {
      host = [[[NSURL URLWithString:url] host] retain];
    }
    
    lastCheckTime = now;
  }
  
  return host;
}

int main(int argc, char **argv) 
{
  NSArray *_blocked;
      _blocked = [[[NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/.config/blocked-sites", NSHomeDirectory()] encoding:NSUTF8StringEncoding error:nil]
                  componentsSeparatedByString:@"\n"] retain];
  
  while(true) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new]; 

    NSString *activeApp = [[[NSWorkspace sharedWorkspace] activeApplication] objectForKey:@"NSApplicationName"];      
    
    if([browserScripts() objectForKey: activeApp]) {
      NSString *host = currentHost(activeApp); 
      if(host) {
        if([_blocked containsObject: host]) {

          NSDictionary *err;
          NSString *killTabScript;
          if ([activeApp isEqualToString:@"Safari"]) {
            killTabScript = [NSString stringWithFormat:@"tell application \"%@\" to tell window 1 to close current tab", activeApp];
          } else if ([activeApp isEqualToString:@"Google Chrome"]) {
            killTabScript = [NSString stringWithFormat:@"tell application \"%@\" to close active tab of window 1", activeApp];            
          }
          NSAppleScript *script = [[NSAppleScript alloc] initWithSource:killTabScript];
          NSAppleEventDescriptor *ret = [script executeAndReturnError:&err];

          //NSLog(@"killed last.");
        }
        [host release];
      }
    }
    
    [pool release];
    
    sleep(1);
  }
}

