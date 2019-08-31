//
//  CarouselCollection.swift
//  Carousel
//
//  Created by 정현화 on 10/08/2019.
//  Copyright © 2019 정현화. All rights reserved.
//

import UIKit

open class CarouselCollection: UICollectionViewFlowLayout {
    
    private struct LayoutState {
        var size: CGSize
        func isEqual(_ otherState: LayoutState) -> Bool {
            return self.size.equalTo(otherState.size)
        }
    }
    
    @IBInspectable open var sideItemAlpha: CGFloat = 0.6
    @IBInspectable open var sideItemScale: CGFloat = 0.6
    private var state = LayoutState(size: CGSize.zero)
    private var cachedItemsAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private let spacing: CGFloat = 20
    
    private var continuousFocusedIndex: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        let offset = collectionView.contentOffset.x
        return offset / (itemSize.width + spacing)
    }
    
    open override func prepare() {
        super.prepare()
        let currentState = LayoutState(size: self.collectionView!.bounds.size)
        
        if !self.state.isEqual(currentState) {
            self.setupCollectionView()
            self.updateLayout()
            self.state = currentState
        }
        
        guard let collectionView = self.collectionView else { return }
        let itemsCount = collectionView.numberOfItems(inSection: 0)
        for item in 0..<itemsCount {
            let indexPath = IndexPath(item: item, section: 0)
            cachedItemsAttributes[indexPath] = createAttributesForItem(at: indexPath)
        }
    }
    
    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cachedItemsAttributes
            .map { $0.value }
            .filter { $0.frame.intersects(rect) }
            .map { self.shiftedAttributes(from: $0) }
    }
    
    open override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView , !collectionView.isPagingEnabled,
            let layoutAttributes = self.layoutAttributesForElements(in: collectionView.bounds)
            else { return super.targetContentOffset(forProposedContentOffset: proposedContentOffset) }
        
        let midSide = collectionView.bounds.size.width / 2
        let proposedContentOffsetCenterOrigin = proposedContentOffset.x + midSide
        
        var targetContentOffset: CGPoint
        let closest = layoutAttributes.sorted { abs($0.center.x - proposedContentOffsetCenterOrigin) < abs($1.center.x - proposedContentOffsetCenterOrigin) }.first ?? UICollectionViewLayoutAttributes()
        targetContentOffset = CGPoint(x: floor(closest.center.x - midSide), y: proposedContentOffset.y)
        
        return targetContentOffset
    }
    
    open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        if newBounds.size != collectionView?.bounds.size { cachedItemsAttributes.removeAll() }
        return true
    }
    
    private func setupCollectionView() {
        guard let collectionView = self.collectionView else { return }
        if collectionView.decelerationRate != UIScrollView.DecelerationRate.fast {
            collectionView.decelerationRate = UIScrollView.DecelerationRate.fast
        }
    }
    
    private func updateLayout(){
        guard let collectionView = self.collectionView else { return }
        
        let collectionSize = collectionView.frame.size
        
        let yInset = (collectionSize.height - self.itemSize.height) / 2
        let xInset = (collectionSize.width - self.itemSize.width) / 2
        self.sectionInset = UIEdgeInsets.init(top: yInset, left: xInset, bottom: yInset, right: xInset)
        self.minimumLineSpacing = spacing
    }
    
    private func createAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        guard let collectionView = collectionView else { return nil }
        attributes.frame.size = self.itemSize
        attributes.frame.origin.y = (collectionView.frame.height - self.itemSize.height) / 2
        attributes.frame.origin.x = CGFloat(indexPath.item) * (self.itemSize.width + spacing) + (collectionView.frame.size.width / 2 - self.itemSize.height / 2)
        attributes.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        return attributes
    }
    
    private func shiftedAttributes(from attributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        guard let attributes = attributes.copy() as? UICollectionViewLayoutAttributes else { fatalError("Couldn't copy attributes") }
        let roundedFocusedIndex = round(continuousFocusedIndex)
        guard attributes.indexPath.item != Int(roundedFocusedIndex) else { return attributes }
        let shiftArea = (roundedFocusedIndex - 0.5)...(roundedFocusedIndex + 0.5)
        let distanceToClosestIdentityPoint = min(abs(continuousFocusedIndex - shiftArea.lowerBound), abs(continuousFocusedIndex - shiftArea.upperBound))
        let normalizedShiftFactor = distanceToClosestIdentityPoint * 2
        let translation = spacing * normalizedShiftFactor
        let translationDirection: CGFloat = attributes.indexPath.item < Int(roundedFocusedIndex) ? -1 : 1
        
        guard let collectionView = self.collectionView else { return attributes }
        let collectionCenter = collectionView.frame.size.width/2
        let offset = collectionView.contentOffset.x
        let normalizedCenter = attributes.center.x - offset
        let maxDistance = self.itemSize.width + self.minimumLineSpacing
        let distance = min(abs(collectionCenter - normalizedCenter), maxDistance)
        
        let ratio = (maxDistance - distance)/maxDistance
        var alpha: CGFloat = 0.0
        if (translationDirection == -1 ){
            alpha = ratio * (1 - self.sideItemAlpha) + self.sideItemAlpha * normalizedCenter/200
        } else if (translationDirection == 1){
            alpha = ratio * (1 - self.sideItemAlpha) + (self.sideItemAlpha * abs(normalizedCenter-collectionView.frame.size.width)/200)
        }
        var scale: CGFloat = 0.0
        if (translationDirection == -1 ){
            scale = ratio * (1 - self.sideItemScale) + self.sideItemScale * normalizedCenter/200 + 0.3
        } else if (translationDirection == 1){
            scale = ratio * (1 - self.sideItemScale) + (self.sideItemScale * abs(normalizedCenter-collectionView.frame.size.width)/200) + 0.3
        }
        
        attributes.alpha = alpha
        attributes.zIndex = Int(alpha * 10)
        attributes.transform3D = CATransform3DScale(attributes.transform3D, scale, scale, scale)
        attributes.transform3D = CATransform3DTranslate(attributes.transform3D, translationDirection*(translation-5.0), 0, 0)
        
        return attributes
    }
}

