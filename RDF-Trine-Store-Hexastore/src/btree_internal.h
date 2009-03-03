#ifndef _BTREE_INTERNAL_H
#define _BTREE_INTERNAL_H

// #define BRANCHING_SIZE	124
#define BRANCHING_SIZE	252
// #define BRANCHING_SIZE	510
// #define BRANCHING_SIZE	1022
// #define BRANCHING_SIZE	14
// #define BRANCHING_SIZE	4

static uint32_t HX_BTREE_NODE_ROOT	= 1;
static uint32_t HX_BTREE_NODE_LEAF	= 2;

hx_btree_node* hx_new_btree_root ( hx_storage_manager* s );
hx_btree_node* hx_new_btree_node ( hx_storage_manager* s );
int hx_free_btree_node ( hx_storage_manager* s, hx_btree_node* node );

list_size_t hx_btree_size ( hx_storage_manager* s, hx_btree_node* node );

int hx_btree_node_debug ( char* string, hx_storage_manager* s, hx_btree_node* node );
int hx_btree_tree_debug ( char* string, hx_storage_manager* s, hx_btree_node* node );
int hx_btree_node_add_child ( hx_storage_manager* s, hx_btree_node* node, hx_node_id n, uint64_t child );
uint64_t hx_btree_node_get_child ( hx_storage_manager* s, hx_btree_node* node, hx_node_id n );
int hx_btree_node_remove_child ( hx_storage_manager* s, hx_btree_node* node, hx_node_id n );

hx_btree_node* hx_btree_node_next_neighbor ( hx_storage_manager* s, hx_btree_node* node );
hx_btree_node* hx_btree_node_prev_neighbor ( hx_storage_manager* s, hx_btree_node* node );
int hx_btree_node_set_parent ( hx_storage_manager* s, hx_btree_node* node, hx_btree_node* parent );
int hx_btree_node_set_next_neighbor ( hx_storage_manager* s, hx_btree_node* node, hx_btree_node* next );
int hx_btree_node_set_prev_neighbor ( hx_storage_manager* s, hx_btree_node* node, hx_btree_node* prev );

int hx_btree_node_has_flag ( hx_storage_manager* s, hx_btree_node* node, uint32_t type );
int hx_btree_node_set_flag ( hx_storage_manager* s, hx_btree_node* node, uint32_t type );
int hx_btree_node_unset_flag ( hx_storage_manager* s, hx_btree_node* node, uint32_t type );

uint64_t hx_btree_node_search ( hx_storage_manager* s, hx_btree_node* root, hx_node_id key );
int hx_btree_node_insert ( hx_storage_manager* s, hx_btree_node** _root, hx_node_id key, uint64_t value );
int hx_btree_node_remove ( hx_storage_manager* s, hx_btree_node** _root, hx_node_id key );
void hx_btree_node_traverse ( hx_storage_manager* s, hx_btree_node* node, hx_btree_node_visitor* before, hx_btree_node_visitor* after, int level, void* param );

#endif