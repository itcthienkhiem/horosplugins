//
//  PLDocumentView.h
//  PrintingLayout
//
//  Created by Benoit Deville on 19.11.12.
//
//

#import <Cocoa/Cocoa.h>
#import "PLLayoutView.h"
#import "PLUtils.h"

@interface PLDocumentView : NSView
{
    BOOL        isDraggingDestination;
    BOOL        fullWidth;
    
    CGFloat     sideMargin;
    CGFloat     topMargin;
    CGFloat     bottomMargin;
    
    paperSize   pageFormat;
    CGFloat     pageWidth;      // keep or not?
    CGFloat     pageHeight;     // keep or not?
//    scrollType  scrollingMode;  // to delete
    
    int         currentPage;
}

@property BOOL fullWidth, isDraggingDestination;
@property CGFloat topMargin, bottomMargin, sideMargin;
@property (nonatomic, setter = setPageFormat:) paperSize pageFormat;
//@property scrollType scrollingMode;
@property int currentPage;

- (void)resizePLDocumentView;
- (void)newPage;
- (void)insertPageAtIndex:(NSUInteger)index;
- (void)goToPage:(NSUInteger)pageNumber;
- (void)saveDocumentViewToPDF;
- (IBAction)insertImage:(id)sender;
- (IBAction)insertSerie:(id)sender;

@end