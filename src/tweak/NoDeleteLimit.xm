#import "headers/WAMessage.h"

#import "_Pr0_Utils.h"


%group GROUP_NO_DELETE_LIMIT

    %hook WAMessage

        -(_Bool)canBeRevoked {
            return true;
        }

    %end

%end



%ctor {

	if (FUNCTION_prefGetBool(@"pref_no_delete_limit")) {
		FUNCTION_logEnabling(@"No Delete Limit");
		%init(GROUP_NO_DELETE_LIMIT);
	} 

}
