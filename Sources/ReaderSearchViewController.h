//
//  ReaderSearchViewController.h
//  Reader
//
//  Created by Hungju Lu on 22/01/2015.
//
//

#import <UIKit/UIKit.h>
#import "ReaderDocument.h"
@class ReaderSearchViewController;

@protocol ReaderSearchViewDelegate <NSObject>
@required
- (void)searchViewController:(ReaderSearchViewController *)controller
                    gotoPage:(NSInteger)page
           withSearchResults:(NSArray *)results;
- (void)searchViewController:(ReaderSearchViewController *)controller
       producedSearchResults:(NSDictionary *)results;
- (void)searchViewController:(ReaderSearchViewController *)controller
                    gotoPage:(NSInteger)page;
@end

@interface ReaderSearchViewController : UITableViewController

@property (weak) id<ReaderSearchViewDelegate> delegate;
@property (strong, nonatomic) ReaderDocument *document;

@end
