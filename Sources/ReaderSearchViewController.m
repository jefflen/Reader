//
//  ReaderSearchViewController.m
//  Reader
//
//  Created by Hungju Lu on 22/01/2015.
//
//

#import "ReaderSearchViewController.h"
#import "Scanner.h"
#import "CGPDFDocument.h"

@interface ReaderSearchViewController () <UISearchBarDelegate>
{
    NSOperationQueue *operationQueue;
    CGPDFDocumentRef documentRef;
    NSMutableDictionary *searchedResults;
    NSInteger currentSelectedSearch;
}
@property (strong, nonatomic) UISearchBar *searchBar;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;
@end

@implementation ReaderSearchViewController

- (void)setDocument:(ReaderDocument *)document
{
    _document = document;
    documentRef = CGPDFDocumentCreateUsingUrl((__bridge CFURLRef)document.fileURL, document.password);
}

- (void)viewDidLoad
{
    operationQueue = [[NSOperationQueue alloc] init];
    searchedResults = [[NSMutableDictionary alloc] init];
    currentSelectedSearch = -1;
    
    [self configureView];
}

- (void)configureView
{
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44.0)];
    self.searchBar.delegate = self;
    self.tableView.tableHeaderView = self.searchBar;
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44.0)];
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(self.view.frame.size.width / 2 - 11, 0, 22, 22)];
    self.activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin|
                                              UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    [footerView addSubview:self.activityIndicator];
    self.tableView.tableFooterView = footerView;
    self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    self.activityIndicator.hidesWhenStopped = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

#pragma mark - <UISearchBarDelegate>

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if (searchText.length) {
        [self performSearch:searchText completion:^{
            [self.tableView reloadData];
        }];
    }
    else {
        [searchedResults removeAllObjects];
        [self.tableView reloadData];
        [self.delegate searchViewController:self
                      producedSearchResults:nil];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [operationQueue cancelAllOperations];
    [searchedResults removeAllObjects];
    [self.tableView reloadData];
    [self.delegate searchViewController:self
                  producedSearchResults:nil];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    currentSelectedSearch += 1;
    if (currentSelectedSearch >= searchedResults.allKeys.count) {
        currentSelectedSearch = 0;
    }
    
    if (searchedResults.allKeys.count == 0) {
        return;
    }
    
    NSInteger section = [self shouldShowsPageJump] ? 1 :0;
    NSInteger row = currentSelectedSearch;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
    [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionBottom];
    
    NSArray *keys = [searchedResults.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSNumber *pageNumber = (NSNumber *)keys[row];
    [self.delegate searchViewController:self gotoPage:pageNumber.integerValue];
}

- (void)performSearch:(NSString *)searchText completion:(void (^)())completion
{
    currentSelectedSearch = -1;
    [operationQueue cancelAllOperations];
    [searchedResults removeAllObjects];
    completion();
    [self.delegate searchViewController:self
                  producedSearchResults:searchedResults];
    
    __block NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.activityIndicator startAnimating];
        }];
        
        currentSelectedSearch = -1;
        size_t pageCount = CGPDFDocumentGetNumberOfPages(documentRef);
        NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
        for (int i = 0; i < pageCount; i++) {
            if ([operation isCancelled]) break;
            NSInteger pageNumber = i + 1;
            CGPDFPageRef pdfPage = CGPDFDocumentGetPage(documentRef, pageNumber);
            Scanner *scanner = [Scanner scannerWithPage:pdfPage];
            NSArray *selections = [scanner select:searchText];
            for (Selection *selection in selections) {
                if ([operation isCancelled]) break;
                NSMutableArray *pageResult = results[@(pageNumber)];
                if (!pageResult) {
                    pageResult = [[NSMutableArray alloc] init];
                    results[@(pageNumber)] = pageResult;
                }
                [pageResult addObject:selection];
            }
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if ([operation isCancelled]) return;
            [self.activityIndicator stopAnimating];
            searchedResults = results;
            completion();
            [self.delegate searchViewController:self
                          producedSearchResults:searchedResults];
        }];
    }];
    
    [operationQueue addOperation:operation];
}

- (BOOL)searchTextContainsNumberOnly
{
    NSCharacterSet *_NumericOnly = [NSCharacterSet decimalDigitCharacterSet];
    NSCharacterSet *myStringSet = [NSCharacterSet characterSetWithCharactersInString:self.searchBar.text];
    return [_NumericOnly isSupersetOfSet:myStringSet] && self.searchBar.text.length;
}

- (BOOL)shouldShowsPageJump
{
    if (![self searchTextContainsNumberOnly]) return NO;
    size_t pageCount = CGPDFDocumentGetNumberOfPages(documentRef);
    NSInteger searchTextNumber = self.searchBar.text.integerValue;
    return (searchTextNumber < pageCount);
}

#pragma mark - <UITableViewDataSource>

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([self shouldShowsPageJump]) {
        return 2;
    }
    else {
        return 1;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([self shouldShowsPageJump]) {
        if (section == 0) {
            return self.searchBar.text.length ? 1 : 0;
        }
        else {
            return searchedResults.allKeys.count;
        }
    }
    else {
        return searchedResults.allKeys.count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if ([self shouldShowsPageJump]) {
        if (section == 0) {
            return self.searchBar.text.length ? @"Page" : @"";
        }
        else {
            return searchedResults.allKeys.count > 0 ? @"Text" : @"";
        }
    }
    else {
        return searchedResults.allKeys.count > 0 ? @"Text" : @"";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    
    if ([self shouldShowsPageJump]) {
        if (indexPath.section == 0) {
            cell.textLabel.text = [NSString stringWithFormat:@"Jump to Page %@", self.searchBar.text];
        }
        else {
            NSArray *keys = [searchedResults.allKeys sortedArrayUsingSelector:@selector(compare:)];
            NSNumber *pageNumber = (NSNumber *)keys[indexPath.row];
            NSInteger displayNumber = pageNumber.integerValue;
            cell.textLabel.text = [NSString stringWithFormat:@"Page %ld", (long)displayNumber];
        }
    }
    else {
        NSArray *keys = [searchedResults.allKeys sortedArrayUsingSelector:@selector(compare:)];
        NSNumber *pageNumber = (NSNumber *)keys[indexPath.row];
        NSInteger displayNumber = pageNumber.integerValue;
        cell.textLabel.text = [NSString stringWithFormat:@"Page %ld", (long)displayNumber];
    }
    
    return cell;
}

#pragma mark - <UITableViewDelegate>

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self shouldShowsPageJump]) {
        if (indexPath.section == 0) {
            NSInteger searchTextNumber = self.searchBar.text.integerValue;
            [self.delegate searchViewController:self gotoPage:searchTextNumber withSearchResults:nil];
        }
        else {
            currentSelectedSearch = indexPath.row;
            NSArray *keys = [searchedResults.allKeys sortedArrayUsingSelector:@selector(compare:)];
            NSNumber *pageNumber = (NSNumber *)keys[indexPath.row];
            NSArray *results = searchedResults[pageNumber];
            NSInteger displayNumber = pageNumber.integerValue;
            [self.delegate searchViewController:self gotoPage:displayNumber withSearchResults:results];
        }
    }
    else {
        currentSelectedSearch = indexPath.row;
        NSArray *keys = [searchedResults.allKeys sortedArrayUsingSelector:@selector(compare:)];
        NSNumber *pageNumber = (NSNumber *)keys[indexPath.row];
        NSArray *results = searchedResults[pageNumber];
        NSInteger displayNumber = pageNumber.integerValue;
        [self.delegate searchViewController:self gotoPage:displayNumber withSearchResults:results];
    }
}

@end
