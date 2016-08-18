local msg = {
    -- 返回成功
    MSG_SUCCESS				                ={"0", "ok!"},
    MSG_SUCCESS_WITH_RESULT			        ={"0", "%s"},

    --> 参数错误
    MSG_ERROR_REQ_FAILED_GET_SECRET                     ={"ME01002", "appKey error"},

    MSG_ERROR_ACCESS_TOKEN_NOT_MATCH                    ={"ME01003", "access token not matched"},
    MSG_ERROR_ACCESS_TOKEN_EXPIRE                       ={"ME01004", "access token expired"},
    MSG_ERROR_ACCESS_TOKEN_NO_AUTH                      ={"ME01005", "access token not this authorization"},


    MSG_ERROR_REQ_BAD_JSON                              ={"ME01006", "error json data!"},

    MSG_ERROR_REQ_SIGN                                  ={"ME01019", "sign is not match!"},

    --> mysql
    MSG_DO_MYSQL_FAILED		                            ={"ME01020", "mysql failed!"},
    --> redis
    MSG_DO_REDIS_FAILED		                            ={"ME01021", "redis failed!"},
    --> 系统错误
    SYSTEM_ERROR                                        ={"ME01022", "internal data error!"},

    MSG_ERROR_REQ_ARG			                        ={"ME01023", "%s is error!"},
    MSG_ERROR_REQ_NO_BODY                               ={"ME01024", "http body is null!"},

    --> http
    MSG_DO_HTTP_FAILED		                            ={"ME01025", "http failed!"},



    --> 结果错误
    MSG_ERROR_REQ_CODE			                        ={"ME18001", "%s!"},
    MSG_ERROR_USER_NAME_EXIST		                    ={"ME18002", "user name is already exist!"},
    MSG_ERROR_SINA_OAUTH_NOT_EXIST	                    ={"ME18003", "sina oauth is not exist in db!"},

    MSG_ERROR_MORE_RECORD	                            ={"ME18004", "%s has more record in db!"},

    MSG_ERROR_FIELD_NOT_EXIST	                        ={"ME18005", "this input field does not exist"},
    MSG_ERROR_IMEI_HAS_NOT_BIND                         ={"ME18006", "IMEI has not bind!"},
    MSG_ERROR_SINA_OAUTH_IS_EXPIRE                      ={"ME18007", "sina oauth access token has expire!"},
    MSG_ERROR_NO_POWER_ON                               ={"ME18008", "mirrtalk is not power on!"},
    MSG_ERROR_CONFIG_NOT_EXIST	                        ={"ME18009", "default config does not exist!"},
    MSG_ERROR_ACCOUNT_NOT_EXIST                         ={"ME18010", "this third account does not exists!"},
    MSG_ERROR_ACCOUNT_EXIST                             ={"ME18011", "this third account has existed!"},
    MSG_ERROR_MTNUM_NO_ACCOUNT_ID                       ={"ME18012", "this mirrtalkNumber has not accountID"},

    -- weibo group
    MSG_ERROR_CANNOT_DEL                                ={"ME18013", "this user cannot be deleted"},
    MSG_ERROR_CODE_USER_NO_GROUP                        ={"ME18014", "this user hasn't this group"},

    MSG_ERROR_ACCOUNT_ID_NO_MONEY                       ={"ME18015", "this accountID has no finance information!"},
    MSG_ERROR_NO_DAOKE_PWD                              ={"ME18016", "no daoke password"},
    MSG_ERROR_MONEY_NOT_ENOUGH_2                        ={"ME18017", "the withdraw amount is larger than the apply withdraw amount:%s"},
    MSG_ERROR_NO_MONEY                                  ={"ME18018", "this user has no money"},
    MSG_ERROR_NOT_ALLOW_CHANGE_DEPOSIT_TYPE             ={"ME18019", "deposit type is valid, not allow to change it"},
    MSG_ERROR_NOT_ALLOW_WITHDRAW                        ={"ME18020", "no right to withdraw the deposit"},
    MSG_ERROR_NOT_ALLOW_EXCHANGE                        ={"ME18021", "no right to exchange the WEME"},


    MSG_ERROR_DEL_TOO_MANY                              ={"ME18025", "delete too many members"},

    -- reward
    MSG_ERROR_IMEI_EXIST	                        ={"ME18030", "IMEI is already exist!"},
    MSG_ERROR_IMEI_NOT_EXIST	                        ={"ME18031", "IMEI is not exist!"},
    MSG_ERROR_IMEI_ILLEGAL                              ={"ME18032", "IMEI is illegal!"},
    MSG_ERROR_NO_WITHDRAW_ACCOUNT                       ={"ME18033", "no account of withdrawing"},
    MSG_ERROR_NO_DEPOSIT_PWD                            ={"ME18034", "no deposit password"},
    MSG_ERROR_DEPOSIT_PWD_NOT_MATCH                     ={"ME18035", "deposit password is not matched"},
    MSG_ERROR_NOT_PAY_DEPOSIT                           ={"ME18036", "the user hasn't paid the deposit"},
    MSG_ERROR_MONEY_NOT_ENOUGH                          ={"ME18037", "the applying amount is larger than the usable amount:%s"},
    MSG_ERROR_TIME_TOO_EARLY                            ={"ME18038", "it's not up to the withdrawable time:%s"},
    MSG_ERROR_WECODE_NOT_EXIST	                        ={"ME18039", "WECODE is not exist!"},
    MSG_ERROR_WECODE_EXPIRE                             ={"ME18040", "WECODE has expired!"},
    MSG_ERROR_NOT_APPLY_QUIT_CONTRACT                   ={"ME18041", "the user hasn't applied quit contract"},
    MSG_ERROR_NOT_APPLY_EXCHANGE                        ={"ME18042", "the user hasn't applied exchanging mirrtalk"},
    MSG_ERROR_IMEI_UNUSABLE                             ={"ME18043", "the IMEI:%s is unusable"},
    MSG_ERROR_REWARD_TYPE_NOT_EXIST			={"ME18044", "reward type is not exist!"},
    MSG_ERROR_REWARD_TYPE_UNUSABLE                      ={"ME18045", "the reward type is unusable"},
    MSG_ERROR_DEPOSIT_TYPE_ILLEGAL                      ={"ME18046", "the deposit type is illegal!"},
    MSG_ERROR_DEPOSIT_TYPE_UNUSABLE                     ={"ME18047", "the deposit type is unusable"},
    MSG_ERROR_DEPOSIT_AMOUNT_NOT_MATCH                  ={"ME18048", "the input deposit amount is not match the given deposit amount"},
    MSG_ERROR_HAS_SAME_REWARD_TYPE                      ={"ME18049", "the user has the same rewards type"},
    MSG_ERROR_WECODE_UNUSABLE                           ={"ME18050", "WECODE has expired!"},
    MSG_ERROR_BUSSINESS_ID_NOT_EXIST	              	={"ME18051", "business ID not exist!"},
    -- end of reward

    -- weibo group
    MSG_ERROR_GROUP_EXIST				={"ME18052", "this group is already exist!"},
    MSG_ERROR_ACCOUNT_ID_NOT_EXIST                      ={"ME18053", "this accountID is not exist!"},
    MSG_ERROR_GROUP_ID_NOT_EXIST                        ={"ME18054", "this groupID is not exist!"},
    MSG_ERROR_GROUP_ID_UNUSABLE                         ={"ME18055", "this groupID is unusable"},
    MSG_ERROR_APPLICANT_NOT_EXIST                       ={"ME18056", "this applyAccountID is not group member!"},
    MSG_ERROR_NO_DEL_RIGHT                              ={"ME18057", "this applicant hasn't delete right"},
    MSG_ERROR_DEL_ACCOUNT_ID_NOT_EXIST                  ={"ME18058", "this deleteAccountID is not group member!"},


    -- account api
    MSG_ERROR_IMEI_HAS_BIND                             ={"ME18059", "IMEI has been bind!"},
    MSG_ERROR_ACCOUNT_ID_NO_SERVICE                     ={"ME18060", "accountID is not in service!"},
    MSG_ERROR_USER_NAME_NOT_EXIST	                ={"ME18061", "user name is not exist!"},
    MSG_ERROR_USER_NAME_UNUSABLE                        ={"ME18062", "user name is not in service!"},
    MSG_ERROR_PWD_NOT_MATCH                             ={"ME18063", "password is not matched"},

    MSG_ERROR_GROUP_MEMBER_EXIST                        ={"ME18064", "this user already in the group"},

    MSG_ERROR_NO_AUTH                                   ={"ME18065", "this user hasn't authorization"},
    MSG_ERROR_AUTH_EXPIRE                               ={"ME18066", "this user hasn't authorization"},

    -- reward api
    MSG_ERROR_IMEI_BEEN_USED	                        ={"ME18067", "IMEI has already been used!"},

    --
    MSG_ERROR_NOT_MOBILE_AUTH	                        ={"ME18068", "user mobile hasn't authorization!"},



    MSG_ERROR_REDIRECT_URL_NOT_MATCH	                ={"ME18069", "redirect url don't match!"},
    MSG_ERROR_AUTHORIZATION_CODE_NOT_EXIST              ={"ME18070", "Authorization code don't exist!"},
    MSG_ERROR_AUTHORIZATION_CODE_EXPIRE                 ={"ME18071", "Authorization code expire!"},

    MSG_ERROR_REFRESH_TOKEN_NOT_EXIST                   ={"ME18072", "Refresh Token don't exist!"},
    MSG_ERROR_REFRESH_TOKEN_EXPIRE                      ={"ME18073", "Refresh Token expire!"},

    MSG_ERROR_CLIENT_APP_KEY_NOT_EXIST                  ={"ME18074", "app key don't exist!"},
    MSG_ERROR_NOT_ALLOW_CREATE_GROUP                  	={"ME18075", "not allow to create group!"},

    --> developer

    MSG_ERROR_WAIT_AUDIT                                ={"ME18076", "developer Info is waiting audit"},
    MSG_ERROR_AUDIT_SUCCESS                             ={"ME18078", "developer Info have audit success"},
    MSG_ERROR_DEVELOPER_NOT_EXIST                       ={"ME18079", "developer has not registered !"},
    MSG_WEBSITE_NOT_EXIST                               ={"ME18080", "website is not exist !"},

    ----WEME Setting
    MSG_ERROR_OFFLINE                                  ={"ME18081", "user must online"},
    MSG_NO_BUSINESS_INFO                                ={"ME18082", "this appKey has no business info !"},
    MSG_ERROR_IMEI_NOT_MATCH_APPKEY                     ={"ME18083", "this IMEI is not match current business appKey !"},


    MSG_ERROR_UNABLE_APP                                ={"ME18084", "this app is unable to use!"},
    MSG_ERROR_DEVELOPER_NOT_VERIFIED                    ={"ME18085", "this developer has not been verified !"},
    MSG_ERROR_APP_NOT_EXIST                             ={"ME18086", "this app is not exist!"},
    MSG_ERROR_CLIENT_APPKEY_NOT_EXIST                   ={"ME18087", "clientAppKey is not exist !"},
    MSG_ERROR_CLIENT_APPKEY_UNUSABLE                    ={"ME18088", "clientAppKey is unusable !"},
    MSG_ERROR_NO_APPLY                                  ={"ME18089", "have no such apply !"},
    MSG_ERROR_CONTROL_FREQUENCY             ={"ME18090", "%s"},    ---- 控制API请求频率,%s,返回执行还需要等X秒(具体环境单位可以不一样) jiang z.s.
    MSG_ERROR_NO_SETTING                ={"ME18091", "%s"},    ---- 用户未设置+键的操作
    MSG_ERROR_TEMPCHANNEL                ={"ME18092", "current channel not start"},    ---- 当前临时频道不是直播模式
    MSG_ERROR_ADMIN_HAS_NO_GROUP                        ={"ME18093", "this administrator has no business group !"},
    -- map api
    MSG_ERROR_FAILED_POINT_MATCH_ROAD			={"ME18110", "location failed!"},

    --sharePoints
    MSG_ERROR_POINTS_UNUSABLE                           ={"ME18094", "this user has no share points"},
    MSG_ERROR_POINTS_HAS_MORE_RECORDS                   ={"ME18095", "the same share points records more than one !"},
    MSG_ERROR_POINTS_HAS_BEEN_GOTTEN                    ={"ME18096", "the share points has been gotten !"},
    MSG_ERROR_POINTS_HAS_OVERTIME                       ={"ME18097", "this share points has overtime"},
    MSG_ERROR_POINTS_MUST_BIG_THAN_ZERO                 ={"ME18098", "user's share points must bigger than zero"},
    MSG_ERROR_LEVEL_OUT_OF_RANGE                        ={"ME18099", "user's level has out of range "},
    MSG_ERROR_POINTS_HAS_DISPATCHED                     ={"ME18100", "share points has dispatched alreadly !"},
    MSG_ERROR_HAS_NO_GROWTH_INFO                        ={"ME18101", "this user has no growth information !"},

    MSG_ERROR_TEMPCHANNEL_LIVE_MODE                   = {"ME18102", "current Channel already live mode"},

    MSG_ERROR_TEMPCHANNEL_DISBAND_MODE               = {"ME18103", "current Channel already disband mode"},

}

return msg
