//
//  ViewController.m
//  PhotoEditingExtensionContaining
//
//  Created by Nanba Takeo on 2014/08/07.
//  Copyright (c) 2014年 GrooveLab. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController
            
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)launchPhotoAppAction:(id)sender {
    NSURL *url = [NSURL URLWithString:@"photos-redirect://"];
    [[UIApplication sharedApplication] openURL:url];
}

@end
