#define HUMAN_AI_HEALTHITEMS "health"
#define HUMAN_AI_AMMUNITION "ammo"
#define HUMAN_AI_GRENADES "grenades"
#define HUMAN_AI_TOOLS "tools"

#define HUMAN_AI_STORAGE_BELT "belt"
#define HUMAN_AI_STORAGE_BACKPACK "backpack"
#define HUMAN_AI_STORAGE_LEFT_POCKET "left_pocket"
#define HUMAN_AI_STORAGE_RIGHT_POCKET "right_pocket"
#define HUMAN_AI_STORAGE_ARMOR "armor"
#define HUMAN_AI_STORAGE_UNIFORM "uniform"

#define ACTION_USING_HANDS (1<<0)
#define ACTION_USING_LEGS (1<<1)
#define ACTION_USING_MOUTH (1<<2)

/// Action is completed, delete this and move onto the next ongoing action
#define ONGOING_ACTION_COMPLETED "completed"
/// Action isn't finished, move onto the next ongoing action
#define ONGOING_ACTION_UNFINISHED "unfinished"
/// Action isn't finished, block any further actions from the AI this tick
#define ONGOING_ACTION_UNFINISHED_BLOCK "unfinished_block"

#define HUMAN_AI_LIFECYCLE_INVALID "invalid"
#define HUMAN_AI_LIFECYCLE_DEAD "dead"
#define HUMAN_AI_LIFECYCLE_PLAYER_CONTROLLED "player_controlled"
#define HUMAN_AI_LIFECYCLE_HARDCRIT "hardcrit"
#define HUMAN_AI_LIFECYCLE_INCAPACITATED "incapacitated"
#define HUMAN_AI_LIFECYCLE_ACTIVE "active"

#define HUMAN_AI_MAX_PATHFINDING_RANGE 45

GLOBAL_LIST_EMPTY(ai_humans)
