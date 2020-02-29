//
//  NSTextView+Rx.swift
//  RxCocoa
//
//  Created by Cee on 8/5/18.
//  Copyright © 2018 Krunoslav Zaher. All rights reserved.
//

#if os(macOS)

import Cocoa
import RxSwift

/// Delegate proxy for `NSTextView`.
///
/// For more information take a look at `DelegateProxyType`.
@available(macOS 10.12, *)
open class RxTextViewDelegateProxy: DelegateProxy<NSTextView, NSTextViewDelegate>, DelegateProxyType, NSTextViewDelegate {

    /*
     * macOS prior to 10.12 does not support weak references to
     * NSTextViews, and Xcode 11.4 beta enforces this as a compile-time
     * error if the build target's deployment target is earlier than
     * 10.12. RxCocoa 5.0.1's deployment target is 10.10.
     *
     * To work around the problem, I've marked this class, and the
     * methods that use it, as only available on 10.12 or later.
     * However, that's not enough to convince the compiler! So I've also
     * changed the type of the weak reference to AnyObject?, and hidden
     * the AnyObject? reference behind a computed property.
     */

    /// Typed parent object.
    public private(set) var textView: NSTextView? {
        get { return unsafeBitCast(_textView, to: NSTextView?.self) }
        set { _textView = newValue }
    }

    private weak var _textView: AnyObject?

    /// Initializes `RxTextViewDelegateProxy`
    ///
    /// - parameter textView: Parent object for delegate proxy.
    init(textView: NSTextView) {
        self._textView = textView
        super.init(parentObject: textView, delegateProxy: RxTextViewDelegateProxy.self)
    }

    public static func registerKnownImplementations() {
        self.register { RxTextViewDelegateProxy(textView: $0) }
    }

    fileprivate let textSubject = PublishSubject<String>()

    // MARK: Delegate methods

    open func textDidChange(_ notification: Notification) {
        let textView: NSTextView = castOrFatalError(notification.object)
        let nextValue = textView.string
        self.textSubject.on(.next(nextValue))
        self._forwardToDelegate?.textDidChange?(notification)
    }

    // MARK: Delegate proxy methods

    /// For more information take a look at `DelegateProxyType`.
    open class func currentDelegate(for object: ParentObject) -> NSTextViewDelegate? {
        return object.delegate
    }

    /// For more information take a look at `DelegateProxyType`.
    open class func setCurrentDelegate(_ delegate: NSTextViewDelegate?, to object: ParentObject) {
        object.delegate = delegate
    }

}

extension Reactive where Base: NSTextView {

    /// Reactive wrapper for `delegate`.
    ///
    /// For more information take a look at `DelegateProxyType` protocol documentation.
    @available(macOS 10.12, *)
    public var delegate: DelegateProxy<NSTextView, NSTextViewDelegate> {
        return RxTextViewDelegateProxy.proxy(for: self.base)
    }

    /// Reactive wrapper for `string` property.
    @available(macOS 10.12, *)
    public var string: ControlProperty<String> {
        let delegate = RxTextViewDelegateProxy.proxy(for: self.base)

        let source = Observable.deferred { [weak textView = self.base] in
            delegate.textSubject.startWith(textView?.string ?? "")
        }.takeUntil(self.deallocated)

        let observer = Binder(self.base) { control, value in
            control.string = value
        }

        return ControlProperty(values: source, valueSink: observer.asObserver())
    }

}

#endif
