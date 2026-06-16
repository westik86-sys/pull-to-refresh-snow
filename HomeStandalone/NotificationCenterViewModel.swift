//
//  NotificationCenterViewModel.swift
//  ProductAvatarPicker
//
//  ViewModel для управления Центром уведомлений
//

import SwiftUI
import UIKit

@MainActor
class NotificationCenterViewModel: ObservableObject {
    enum ExpandTrigger {
        case tap
        case drag
    }
    
    // State - Single Source of Truth
    @Published var isExpanded: Bool = false
    @Published var dragOffset: CGFloat = 0  // Текущее смещение при drag (live)
    @Published var isDragging: Bool = false // Флаг активного drag
    @Published private(set) var lastExpandTrigger: ExpandTrigger = .tap
    
    // Константы
    private let collapsedIslandHeight: CGFloat = 108 // Статус бар (~54) + контент (54)
    private let contentVisibleHeight: CGFloat = 110  // Видимая часть "Главной"
    private let gap: CGFloat = 8                     // Просвет между блоками
    
    // Новые параметры для улучшенного UX
    private let snapThreshold: CGFloat = 0.5        // 50% прогресса для snap
    private let velocityThreshold: CGFloat = 800    // Порог скорости для быстрого свайпа
    private let rubberBandFactor: CGFloat = 0.3     // Сопротивление для overscroll
    private let dragLogStep: CGFloat = 8            // Шаг логирования drag
    
    // Хаптик feedback - только на пороге принятия решения
    private var hasTriggeredThresholdHaptic = false // Флаг срабатывания порогового хаптика
    private var lastLoggedTranslation: CGFloat = .nan
    
    // MARK: - Computed Properties (Single Source of Truth)
    
    /// Прогресс анимации от 0.0 (collapsed) до 1.0 (expanded)
    private func animationProgress(screenHeight: CGFloat) -> CGFloat {
        let maxDragDistance = effectiveMaxDragDistance(screenHeight: screenHeight)
        // ВАЖНО: учитываем dragOffset даже когда isDragging = false
        // чтобы анимация продолжалась плавно от текущей позиции
        
        let effectiveDrag: CGFloat
        
        if isExpanded {
            // Если развернут - drag up сжимает
            effectiveDrag = -dragOffset
        } else {
            // Если свернут - drag down растягивает
            effectiveDrag = dragOffset
        }
        
        // Нормализуем в диапазон 0...1
        let dragProgress = min(max(effectiveDrag / maxDragDistance, 0), 1)
        
        // Базовый прогресс от состояния
        let baseProgress: CGFloat = isExpanded ? 1.0 : 0.0
        
        // Итоговый прогресс = базовый ± drag offset
        if isExpanded {
            // Если развернут, drag offset вычитается
            return max(0, min(1, baseProgress - dragProgress))
        } else {
            // Если свернут, drag offset добавляется
            return max(0, min(1, baseProgress + dragProgress))
        }
    }
    
    /// Высота острова (интерполируется)
    func islandHeight(screenHeight: CGFloat) -> CGFloat {
        let progress = animationProgress(screenHeight: screenHeight)
        let minHeight = collapsedIslandHeight
        // В развернутом состоянии ЦУ занимает ровно первый вьюпорт
        let maxHeight = screenHeight
        
        return minHeight + (maxHeight - minHeight) * progress
    }
    
    /// Y позиция "Главной" (отступ от верха экрана)
    func contentY(screenHeight: CGFloat) -> CGFloat {
        return islandHeight(screenHeight: screenHeight) + gap
    }
    
    /// Высота "Главной" (интерполируется)
    func contentHeight(screenHeight: CGFloat) -> CGFloat {
        let progress = animationProgress(screenHeight: screenHeight)
        let maxHeight = screenHeight - collapsedIslandHeight - gap
        let minHeight = contentVisibleHeight
        
        return maxHeight - (maxHeight - minHeight) * progress
    }
    
    /// Прозрачность текста "Все уведомления" (исчезает быстро)
    func collapsedTextOpacity(screenHeight: CGFloat) -> CGFloat {
        let progress = animationProgress(screenHeight: screenHeight)
        return collapsedTextOpacity(from: progress)
    }
    
    /// Прозрачность текста "Все уведомления" для внешнего прогресса (0...1)
    func collapsedTextOpacity(from progress: CGFloat) -> CGFloat {
        
        // Исчезает в первые 5% прогресса, чтобы минимизировать нахлест с "Важное"
        if progress <= 0.05 {
            return 1.0 - (progress / 0.05)
        } else {
            return 0.0
        }
    }
    
    /// Прозрачность текста "Остров" (появляется в конце)
    func expandedTextOpacity(screenHeight: CGFloat) -> CGFloat {
        let progress = animationProgress(screenHeight: screenHeight)
        
        // Появляется в последние 30% прогресса
        if progress >= 0.7 {
            return (progress - 0.7) / 0.3
        } else {
            return 0.0
        }
    }
    
    /// Нормализованный прогресс появления кнопки "Закрыть" (старт с 0.9)
    func closeButtonRevealProgress(screenHeight: CGFloat) -> CGFloat {
        let progress = animationProgress(screenHeight: screenHeight)
        return closeButtonRevealProgress(from: progress)
    }
    
    /// Нормализованный прогресс появления кнопки из любого внешнего прогресса (0...1)
    func closeButtonRevealProgress(from progress: CGFloat) -> CGFloat {
        // Начинаем заметно позже, чтобы кнопка не появлялась на уходящей "Главной"
        let start: CGFloat = 0.94
        
        guard progress >= start else { return 0 }
        return min(max((progress - start) / (1.0 - start), 0), 1)
    }

    /// Прозрачность кнопки "Закрыть"
    func closeButtonOpacity(screenHeight: CGFloat) -> CGFloat {
        closeButtonRevealProgress(screenHeight: screenHeight)
    }

    /// Вертикальное смещение кнопки "Закрыть" (появление сверху вниз)
    func closeButtonOffsetY(screenHeight: CGFloat) -> CGFloat {
        let reveal = closeButtonRevealProgress(screenHeight: screenHeight)
        let startOffset: CGFloat = -18
        return (1 - reveal) * startOffset
    }
    
    /// Прозрачность контента открытого ЦУ
    /// Плавно появляется при открытии и плавно исчезает при закрытии
    func expandedContentOpacity(screenHeight: CGFloat) -> CGFloat {
        let progress = animationProgress(screenHeight: screenHeight)
        return expandedContentOpacity(from: progress)
    }
    
    /// Прозрачность контента ЦУ для внешнего прогресса (0...1)
    func expandedContentOpacity(from progress: CGFloat) -> CGFloat {
        let start: CGFloat = 0.08
        let end: CGFloat = 0.65
        
        guard progress > start else { return 0 }
        return min(max((progress - start) / (end - start), 0.0), 1.0)
    }
    
    // MARK: - Public Methods
    
    /// Переключение состояния по тапу
    func toggleExpanded() {
        // Легкий хаптик
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        withAnimation(.timingCurve(0.34, 1.15, 0.25, 1.0, duration: 0.8)) {
            if !isExpanded {
                lastExpandTrigger = .tap
            }
            isExpanded.toggle()
            dragOffset = 0
            isDragging = false
        }
        
        let emoji = isExpanded ? "📖" : "📕"
        let status = isExpanded ? "открыт" : "закрыт"
        print("\(emoji) ЦУ \(status) (тап)")
    }
    
    /// Обработка перетаскивания (жест) - LIVE PREVIEW с пороговым хаптиком
    func handleDrag(translation: CGFloat, screenHeight: CGFloat) {
        let maxDragDistance = effectiveMaxDragDistance(screenHeight: screenHeight)
        let wasDragging = isDragging
        isDragging = true
        lastExpandTrigger = .drag
        
        if !wasDragging {
            lastLoggedTranslation = .nan
            print("🧭 [NCDebug] drag-start expanded=\(isExpanded) maxDrag=\(Int(maxDragDistance))")
        }
        
        // Определяем эффективный drag с учетом направления
        let effectiveDrag: CGFloat
        
        if isExpanded {
            // Если развернут - drag up сжимает
            if translation < 0 {
                // Нормальное поведение (сжатие)
                effectiveDrag = translation
            } else {
                // Резиновый эффект для обратного направления
                effectiveDrag = translation * rubberBandFactor
            }
        } else {
            // Если свернут - drag down растягивает
            if translation > 0 {
                // Нормальное поведение (растягивание)
                effectiveDrag = translation
            } else {
                // Резиновый эффект для обратного направления
                effectiveDrag = translation * rubberBandFactor
            }
        }
        
        // Применяем rubber band для overscroll (за пределами maxDragDistance)
        if abs(effectiveDrag) > maxDragDistance {
            let overflow = abs(effectiveDrag) - maxDragDistance
            let rubberBandOverflow = overflow * rubberBandFactor
            dragOffset = (effectiveDrag > 0 ? 1 : -1) * (maxDragDistance + rubberBandOverflow)
        } else {
            dragOffset = effectiveDrag
        }
        
        // Вычисляем текущий прогресс
        let currentProgress = animationProgress(screenHeight: screenHeight)
        
        // Диагностика "обгона": сравниваем путь пальца и визуальный путь острова
        maybeLogDrag(
            translation: translation,
            progress: currentProgress,
            screenHeight: screenHeight
        )
        
        // 🎯 ПОРОГОВЫЙ ХАПТИК - только при пересечении 50%
        // Это момент когда экран "решает" открыться/закрыться
        if !hasTriggeredThresholdHaptic && currentProgress >= snapThreshold {
            // Пересекли порог → хаптик!
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            hasTriggeredThresholdHaptic = true
            print("🎯 Пересечен порог 50% - экран будет открыт")
        } else if hasTriggeredThresholdHaptic && currentProgress < snapThreshold {
            // Вернулись назад за порог → сброс флага
            hasTriggeredThresholdHaptic = false
            print("↩️ Вернулись за порог 50%")
        }
    }
    
    /// Обработка завершения жеста с улучшенной логикой snap
    func handleDragEnd(translation: CGFloat, velocity: CGFloat, screenHeight: CGFloat) {
        // Вычисляем финальный прогресс НА МОМЕНТ отпускания
        let finalProgress = animationProgress(screenHeight: screenHeight)
        
        // Сбрасываем флаги
        hasTriggeredThresholdHaptic = false
        lastLoggedTranslation = .nan
        
        // Определяем направление
        let dragDown = translation > 0
        let dragUp = translation < 0
        
        // Проверяем velocity (быстрый свайп)
        let fastDown = velocity > velocityThreshold
        let fastUp = velocity < -velocityThreshold
        
        // Логика принятия решения (с учетом прогресса И velocity)
        let shouldExpand: Bool
        let shouldCollapse: Bool
        
        if isExpanded {
            // Если уже развернут → проверяем нужно ли свернуть
            shouldCollapse = (dragUp && finalProgress < (1.0 - snapThreshold)) || fastUp
            shouldExpand = false
        } else {
            // Если свернут → проверяем нужно ли развернуть
            shouldExpand = (dragDown && finalProgress > snapThreshold) || fastDown
            shouldCollapse = false
        }
        
        // Легкий хаптик при успешном жесте
        if shouldExpand || shouldCollapse {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
        
        // КРИТИЧЕСКИ ВАЖНО: сбрасываем isDragging БЕЗ анимации
        // чтобы избежать скачка, а затем анимируем только изменение состояния
        isDragging = false
        
        // Анимация к финальному состоянию
        withAnimation(.timingCurve(0.34, 1.15, 0.25, 1.0, duration: 0.8)) {
            // Сначала сбрасываем dragOffset
            dragOffset = 0
            
            // Затем меняем состояние (если нужно)
            if shouldExpand {
                lastExpandTrigger = .drag
                isExpanded = true
                print("📖 ЦУ открыт (progress: \(Int(finalProgress * 100))%, Δ: \(Int(translation))px, v: \(Int(velocity))px/s)")
            } else if shouldCollapse {
                isExpanded = false
                print("📕 ЦУ закрыт (progress: \(Int(finalProgress * 100))%, Δ: \(Int(translation))px, v: \(Int(velocity))px/s)")
            } else {
                // Возврат к текущему состоянию (только сбрасываем dragOffset)
                print("↩️ Жест отменен (progress: \(Int(finalProgress * 100))%, Δ: \(Int(translation))px, v: \(Int(velocity))px/s)")
            }
        }
    }
    
    private func maybeLogDrag(translation: CGFloat, progress: CGFloat, screenHeight: CGFloat) {
        let shouldLog: Bool
        
        if lastLoggedTranslation.isNaN {
            shouldLog = true
        } else {
            shouldLog = abs(translation - lastLoggedTranslation) >= dragLogStep
        }
        
        guard shouldLog else { return }
        lastLoggedTranslation = translation
        
        let visualDelta = islandHeight(screenHeight: screenHeight) - collapsedIslandHeight
        let ratio = translation == 0 ? 0 : visualDelta / translation
        
        print(
            String(
                format: "🧭 [NCDebug] drag raw=%.1f visual=%.1f ratio=%.2f progress=%.3f",
                translation,
                visualDelta,
                ratio,
                progress
            )
        )
    }
    
    private func effectiveMaxDragDistance(screenHeight: CGFloat) -> CGFloat {
        // 1:1 по пути пальца: расстояние drag равно полному ходу острова
        max(screenHeight - collapsedIslandHeight, 1)
    }
}
