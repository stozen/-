//
//  UIMessageInputView_Voice.m
//  shangketong
//
//  Created by sungoin-zbs on 15/10/17.
//  Copyright (c) 2015年 sungoin. All rights reserved.
//

#import "UIMessageInputView_Voice.h"
#import "AudioRecordView.h"
#import "AudioVolumeView.h"
#import "AudioManager.h"

typedef NS_ENUM(NSInteger, UIMessageInputView_VoiceState) {
    UIMessageInputView_VoiceStateReady,
    UIMessageInputView_VoiceStateRecording,
    UIMessageInputView_VoiceStateCancel
};

@interface UIMessageInputView_Voice ()<AudioRecordViewDelegate>

@property (strong, nonatomic) UILabel *recordTipsLabel;
@property (strong, nonatomic) AudioVolumeView *volumeLeftView;
@property (strong, nonatomic) AudioVolumeView *volumeRightView;
@property (strong, nonatomic) AudioRecordView *recordView;

@property (assign, nonatomic) UIMessageInputView_VoiceState state;
@property (assign, nonatomic) int duration;
@property (strong, nonatomic) NSTimer *timer;
@end

@implementation UIMessageInputView_Voice

- (void)dealloc {
    self.state = UIMessageInputView_VoiceStateReady;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithHexString:@"0xf8f8f8"];

        [self addSubview:self.recordTipsLabel];
        [self addSubview:self.recordView];
        
        _volumeLeftView = [[AudioVolumeView alloc] initWithFrame:CGRectMake(0, 0, kAudioVolumeViewWidth, kAudioVolumeViewHeight)];
        _volumeLeftView.type = AudioVolumeViewTypeLeft;
        _volumeLeftView.hidden = YES;
        [self addSubview:_volumeLeftView];
        
        _volumeRightView = [[AudioVolumeView alloc] initWithFrame:CGRectMake(0, 0, kAudioVolumeViewWidth, kAudioVolumeViewHeight)];
        _volumeRightView.type = AudioVolumeViewTypeRight;
        _volumeRightView.hidden = YES;
        [self addSubview:_volumeRightView];
        
        UILabel *tipLabel = [[UILabel alloc] init];
        tipLabel.font = [UIFont systemFontOfSize:12];
        tipLabel.textColor = [UIColor colorWithRGBHex:0x999999];
        tipLabel.text = @"向上滑动，取消发送";
        [tipLabel sizeToFit];
        [tipLabel setCenterX:CGRectGetWidth(self.bounds) / 2];
        [tipLabel setCenterY:CGRectGetHeight(self.bounds) - 25];
        [self addSubview:tipLabel];
        
        _duration = 0;
        self.state = UIMessageInputView_VoiceStateReady;
    }
    return self;
}

#pragma mark - private method
- (NSString *)formattedTime:(int)duration {
    return [NSString stringWithFormat:@"%02d:%02d", duration / 60, duration % 60];
}

- (void)increaseRecordTime {
    _duration++;
    if (self.state == UIMessageInputView_VoiceStateRecording) {
        //update time label
        self.state = UIMessageInputView_VoiceStateRecording;
    }
}

#pragma mark - RecordTimer
- (void)startTimer {
    _duration = 0;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(increaseRecordTime) userInfo:nil repeats:YES];
}

- (void)stopTimer {
    if (_timer) {
        [_timer invalidate];
        self.timer = nil;
    }
}

#pragma mark - AudioRecordViewDelegate
- (void)recordViewRecordStarted:(AudioRecordView *)recordView {
    
    [_volumeLeftView clearVolume];
    [_volumeRightView clearVolume];
    self.state = UIMessageInputView_VoiceStateRecording;
    [self startTimer];
}


- (void)recordViewRecordFinished:(AudioRecordView *)recordView file:(NSString *)file duration:(NSTimeInterval)duration {
    [self stopTimer];
    if (_state == UIMessageInputView_VoiceStateRecording) {
        if (self.recordSuccessfully) {
            self.recordSuccessfully(file, duration);
        }
    }else if (_state == UIMessageInputView_VoiceStateCancel) {
        // 删除录音文件
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    }
    
    self.state = UIMessageInputView_VoiceStateReady;
    _duration = 0;
}

- (void)recordView:(AudioRecordView *)recordView touchStateChanged:(AudioRecordViewTouchState)touchState {
    if (_state == UIMessageInputView_VoiceStateReady)
        return;
    
    if (touchState == AudioRecordViewTouchStateInside) {
        self.state = UIMessageInputView_VoiceStateRecording;
    }else {
        self.state = UIMessageInputView_VoiceStateCancel;
    }
}

- (void)recordView:(AudioRecordView *)recordView volume:(double)volume {
    [_volumeLeftView addVolume:volume];
    [_volumeRightView addVolume:volume];
}

- (void)recordView:(AudioRecordView *)recordView error:(NSError *)error {
    [self stopTimer];
    if (_state == UIMessageInputView_VoiceStateRecording) {
        [NSObject showHudTipStr:error.domain];
    }
    
    self.state = UIMessageInputView_VoiceStateReady;
    _duration = 0;
}

#pragma mark - setters and getters
- (void)setState:(UIMessageInputView_VoiceState)state {
    _state = state;
    
    switch (_state) {
        case UIMessageInputView_VoiceStateReady:
            _recordTipsLabel.textColor = [UIColor colorWithRGBHex:0x999999];
            _recordTipsLabel.text = @"按住说话";
            _volumeLeftView.hidden = YES;
            _volumeRightView.hidden = YES;
            break;
        case UIMessageInputView_VoiceStateRecording:
            if (_duration < ([AudioManager shared].maxRecordDuration - 5)) {
                _recordTipsLabel.textColor = [UIColor colorWithRGBHex:0x2faeea];
            }else {
                _recordTipsLabel.textColor = [UIColor colorWithRGBHex:0xDE4743];
            }
            _recordTipsLabel.text = [self formattedTime:_duration];
            break;
        case UIMessageInputView_VoiceStateCancel:
            _recordTipsLabel.textColor = [UIColor colorWithRGBHex:0x999999];
            _recordTipsLabel.text = @"松开取消";
            _volumeLeftView.hidden = YES;
            _volumeRightView.hidden = YES;
            break;
        default:
            break;
    }
    
    [_recordTipsLabel sizeToFit];
    [_recordTipsLabel setCenterX:CGRectGetWidth(self.bounds) / 2];
    [_recordTipsLabel setCenterY:20];
    
    if (_state == UIMessageInputView_VoiceStateRecording) {
        _volumeLeftView.center = CGPointMake(_recordTipsLabel.frame.origin.x - _volumeLeftView.frame.size.width/2 - 12, _recordTipsLabel.center.y);
        _volumeLeftView.hidden = NO;
        _volumeRightView.center = CGPointMake(_recordTipsLabel.frame.origin.x + _recordTipsLabel.frame.size.width + _volumeRightView.frame.size.width/2 + 12, _recordTipsLabel.center.y);
        _volumeRightView.hidden = NO;
    }
}

- (UILabel*)recordTipsLabel {
    if (!_recordTipsLabel) {
        _recordTipsLabel = [[UILabel alloc] init];
        _recordTipsLabel.font = [UIFont systemFontOfSize:18];
    }
    return _recordTipsLabel;
}

- (AudioRecordView*)recordView {
    if (!_recordView) {
        _recordView = [[AudioRecordView alloc] initWithFrame:CGRectMake(0, 0, 86, 86)];
        [_recordView setY:62];
        [_recordView setCenterX:CGRectGetWidth(self.bounds) / 2.0];
        _recordView.delegate = self;
    }
    return _recordView;
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
