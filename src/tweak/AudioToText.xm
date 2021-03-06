#import "headers/WAMessage.h"
#import "headers/WAChatCellData.h"
#import "headers/WAMessageAudioSliceView.h"

#import "_Pr0_Utils.h"
#import "_opus_conversor.h"

#import <Speech/Speech.h>


NSLocale* GLOBAL_LOCALE;  // This will be the language locale. Will be loaded from prefs.

bool GLOBAL_IS_PROCESSING = false;  // Just a lock so only one audio is processed simultaneously.



/**
 * Class that does all the audio processing.
 */
@interface Pr0crustes_Transcriber : NSObject

	// Create an autorelease instance.
	+(id)createInstance;

	// Main interface method, transcribes an Opus file.
	-(void)transcribeFile:(NSString *)filePath;

	// Method used to process a .wav file.
	-(void)transcribeWavFile:(NSString *)filePath;

	// Method that will be called as a callback for the recognizer.
	-(void)transcriberCallback:(NSString *)message;

	// Methods to start and stop the loading indicator.
	-(void)startLoadIndicator;
	-(void)stopLoadIndicator;

	@property (strong, nonatomic) UIAlertController* alert;
	@property (strong, nonatomic) UIActivityIndicatorView* loadIndicator;
@end


@implementation Pr0crustes_Transcriber

	+(id)createInstance {
		id instance = [Pr0crustes_Transcriber alloc];
		[instance autorelease];
		return instance;
	}

	-(void)startLoadIndicator {
		self.loadIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
		[self.loadIndicator setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
		[self.loadIndicator setColor:[UIColor redColor]];

		UIView* topView = FUNCTION_getTopView();

		self.loadIndicator.center = topView.center;
		[topView addSubview:self.loadIndicator];

		[self.loadIndicator startAnimating];
	}

	-(void)stopLoadIndicator {
		if (self.loadIndicator) {
			[self.loadIndicator stopAnimating];
			[self.loadIndicator release];
			self.loadIndicator = nil;
		}
	}

	-(void)transcribeFile:(NSString*)fileIn {
		NSString* outFile = [fileIn stringByAppendingString:@".wav"];

		[self startLoadIndicator];

		int result = pr0crustes_opusToWav([fileIn UTF8String], [outFile UTF8String]);

		if (result == PR0CRUSTES_OK) {
			[self transcribeWavFile:outFile];
		} else {
			FUNCTION_tryDeleteFile(outFile);
			FUNCTION_simpleAlert(@"AudioToText Error:\n", [NSString stringWithFormat:@"Code: %i", result]);
			GLOBAL_IS_PROCESSING = false;
		}
	}

	-(void)transcribeWavFile:(NSString *)filePath {
		SFSpeechRecognizer* speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:GLOBAL_LOCALE];
		[speechRecognizer autorelease];

		NSURL* url = [NSURL fileURLWithPath:filePath];

		SFSpeechURLRecognitionRequest* urlRequest = [[SFSpeechURLRecognitionRequest alloc] initWithURL:url];
		[urlRequest autorelease];
		urlRequest.shouldReportPartialResults = true;  // Report only when done.

		[speechRecognizer recognitionTaskWithRequest:urlRequest resultHandler:^(SFSpeechRecognitionResult* result, NSError* error) {

			if (GLOBAL_IS_PROCESSING) {
				GLOBAL_IS_PROCESSING = false;
				FUNCTION_tryDeleteFile(filePath);
			}

			[self stopLoadIndicator];

			NSString *message = error ? [NSString stringWithFormat:@"Error processing text -> \n%@\nMay be your connection.", error] : result.bestTranscription.formattedString;

			if (self.alert) {  
				// If an alert is present, first destroy it, calling the callback in the completion.
				[self.alert dismissViewControllerAnimated:true completion:^{
					[self transcriberCallback:message];
				}];
			} else {
				[self transcriberCallback:message];
			}

		}];
	}

	-(void)transcriberCallback:(NSString *)message {
		self.alert = [UIAlertController alertControllerWithTitle:@"AudioToText Result:\n" message:message preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
		[self.alert addAction:closeAction];

		FUNCTION_presentAlert(self.alert, true);
	}

@end



%group GROUP_AUDIO_TO_TEXT

	%hook WAMessageAudioSliceView

	    %property (nonatomic, assign) BOOL pr0crustes_didConnectButton; // Make sure the button is only connected once.

		%new
		-(void)pr0crustes_doAudioToText {

			GLOBAL_IS_PROCESSING = true;

			WAChatCellData* data = MSHookIvar<WAChatCellData *>(self, "_lastCellData");
			NSString* fileIn = [[data message] mediaPath];

			Pr0crustes_Transcriber* transcriber = [Pr0crustes_Transcriber createInstance];
			[transcriber transcribeFile:fileIn];
		}

		%new
		-(void)pr0crustes_onButtonHold:(UILongPressGestureRecognizer *)recognizer {
			if (recognizer.state == UIGestureRecognizerStateBegan && !GLOBAL_IS_PROCESSING) {
				[self pr0crustes_doAudioToText];
			}
		}

		-(void)layoutSubviews {
			%orig;

			if (!self.pr0crustes_didConnectButton) {
				UIButton* button = MSHookIvar<UIButton *>(self, "_playPauseButton");
				UILongPressGestureRecognizer* buttonHold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pr0crustes_onButtonHold:)];
				[button addGestureRecognizer:buttonHold];

				self.pr0crustes_didConnectButton = true;
			}
		}

	%end


	%hook NSBundle

		-(id)infoDictionary {
			NSMutableDictionary *dictionary = [%orig mutableCopy];
			dictionary[@"NSSpeechRecognitionUsageDescription"] = @"[BetterW] -> Needed for AudioToText.";
			return dictionary;
		}

	%end

%end



%ctor {

	if (FUNCTION_prefGetBool(@"pref_audio_to_text")) {
		FUNCTION_logEnabling(@"Audio To Text");
		GLOBAL_LOCALE = [NSLocale localeWithLocaleIdentifier:FUNCTION_prefGet(@"pref_audio_to_text_locale")];
		%init(GROUP_AUDIO_TO_TEXT);
	}

}
