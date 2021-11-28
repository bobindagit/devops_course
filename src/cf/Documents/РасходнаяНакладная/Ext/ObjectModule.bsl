﻿
Процедура ПередЗаписью(Отказ, РежимЗаписи, РежимПроведения)
	СуммаПоДокументу = СписокНоменклатуры.Итог("Сумма");
КонецПроцедуры

Процедура ОбработкаПроведения(Отказ, РежимПроведения)
	
	ОбработкаПроведенияОУ (Отказ);
	ОбработкаПроведенияБУ (Отказ);
	
КонецПроцедуры

Процедура ОбработкаПроведенияОУ (Отказ)
	
	// Определение текущего метода списания себестоимости
	МетодСписания = РегистрыСведений.УчетнаяПолитика.ПолучитьПоследнее(Дата).МетодСписания;
	
	Если Не ЗначениеЗаполнено(МетодСписания) Тогда
		Сообщение = Новый СообщениеПользователю;
		Сообщение.Текст = "Не заполнен метод списания учетной политики";
		Сообщение.Сообщить();
		
		Отказ = Истина;
		Возврат;
	КонецЕсли;        	
	
	ПорядокСортировкиПартий = ? (МетодСписания = Перечисления.МетодыСписания.ЛИФО, " УБЫВ", "");
	
	
	// ДВИЖЕНИЯ ПО РЕГИСТРУ ОСТАТКИ НОМЕНКЛАТУРЫ (НОВАЯ МЕТОДИКА ПРОВЕДЕНИЯ)	
	
	// Запрос получения данных для формирования движений
	Запрос = Новый Запрос;
	Запрос.МенеджерВременныхТаблиц = Новый МенеджерВременныхТаблиц; // будем несколько раз использовать временную таблицу данных ТЧ
	Запрос.Текст = 
	"ВЫБРАТЬ
	|	РасходнаяНакладнаяСписокНоменклатуры.Номенклатура КАК Номенклатура,
	|	СУММА(РасходнаяНакладнаяСписокНоменклатуры.Количество) КАК Количество
	|ПОМЕСТИТЬ ВТ_ТабЧасть
	|ИЗ
	|	Документ.РасходнаяНакладная.СписокНоменклатуры КАК РасходнаяНакладнаяСписокНоменклатуры
	|ГДЕ
	|	РасходнаяНакладнаяСписокНоменклатуры.Ссылка = &Ссылка
	|	И НЕ РасходнаяНакладнаяСписокНоменклатуры.Номенклатура.ВидНоменклатуры = &ВидНоменклатурыУслуга
	|
	|СГРУППИРОВАТЬ ПО
	|	РасходнаяНакладнаяСписокНоменклатуры.Номенклатура
	|
	|ИНДЕКСИРОВАТЬ ПО
	|	Номенклатура
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|ВЫБРАТЬ
	|	ВТ_ТабЧасть.Номенклатура КАК Номенклатура,
	|	ВТ_ТабЧасть.Количество КАК Количество
	|ИЗ
	|	ВТ_ТабЧасть КАК ВТ_ТабЧасть";
	
	Запрос.УстановитьПараметр("Ссылка", Ссылка);	
	Запрос.УстановитьПараметр("ВидНоменклатурыУслуга", Перечисления.ВидыНоменклатуры.Услуга);
	
	РезультатДанныеТЧ = Запрос.Выполнить();
	Выборка = РезультатДанныеТЧ.Выбрать();
	
	// Формирование набора записей, запись движений в регистр
	Пока Выборка.Следующий() Цикл
		Движение = Движения.ОстаткиНоменклатуры.ДобавитьРасход();
		Движение.Период = Дата;
		Движение.Склад = Склад;
		Движение.Номенклатура = Выборка.Номенклатура;
		Движение.Количество = Выборка.Количество;
	КонецЦикла;
	
	Движения.ОстаткиНоменклатуры.БлокироватьДляИзменения = Истина;
	Движения.ОстаткиНоменклатуры.Записать();
	
	// Запрос получения данных для контроля появления отрицательных остатков
	Запрос.Текст = 
	"ВЫБРАТЬ
	|	ОстаткиНоменклатурыОстатки.Номенклатура.Представление КАК НоменклатураПредставление,
	|	-ОстаткиНоменклатурыОстатки.КоличествоОстаток КАК Превышение
	|ИЗ
	|	РегистрНакопления.ОстаткиНоменклатуры.Остатки(
	|			&МоментВремениВключая,
	|			Номенклатура В
	|					(ВЫБРАТЬ
	|						Т.Номенклатура
	|					ИЗ
	|						ВТ_ТабЧасть КАК Т)
	|				И Склад = &Склад) КАК ОстаткиНоменклатурыОстатки
	|ГДЕ
	|	ОстаткиНоменклатурыОстатки.КоличествоОстаток < 0";
	
	Запрос.УстановитьПараметр("МоментВремениВключая", Новый Граница(МоментВремени()));
	Запрос.УстановитьПараметр("Склад", Склад);
	
	// Если результат запроса не пустой, то вывод данных по превышениям остатка и отказ от проведения документа
	Результат = Запрос.Выполнить();
	Если Не Результат.Пустой() Тогда
		Выборка = Результат.Выбрать();
		Пока Выборка.Следующий() Цикл
			Сообщение = Новый СообщениеПользователю;
			Сообщение.Текст = СтрШаблон("Превышение остатка по номенклатуре %1 в количестве %2 (оперативный учет, регистр ""Остатки номенклатуры"")",
				Выборка.НоменклатураПредставление, Выборка.Превышение);
			Сообщение.Сообщить();
		КонецЦикла;
		
		Отказ = Истина;
		Возврат;
	КонецЕсли;
	
	
	// ДВИЖЕНИЯ ПО РЕГИСТРУ ПАРТИИ НОМЕНКЛАТУРЫ (СТАРАЯ МЕТОДИКА ПРОВЕДЕНИЯ)	
	
	Движения.ПартииНоменклатуры.Записывать = Истина;
	Движения.ПартииНоменклатуры.Записать();
	
	// Установка блокировки данных в регистре Партии товаров по номенклатурам табличной части 
	Блокировка = Новый БлокировкаДанных;
	ЭлементБлокировки = Блокировка.Добавить("РегистрНакопления.ПартииНоменклатуры");
	ЭлементБлокировки.Режим = РежимБлокировкиДанных.Исключительный;
	ЭлементБлокировки.ИсточникДанных = РезультатДанныеТЧ;
	ЭлементБлокировки.ИспользоватьИзИсточникаДанных("Номенклатура", "Номенклатура");
	Блокировка.Заблокировать();
	
	// Запрос получения данных для формирования движений
	Запрос.Текст = 
	"ВЫБРАТЬ
	|	ВТ_ТабЧасть.Номенклатура КАК Номенклатура,
	|	ПРЕДСТАВЛЕНИЕ(ВТ_ТабЧасть.Номенклатура) КАК НоменклатураПредставление,
	|	ВТ_ТабЧасть.Количество КАК КоличествоВДокументе,
	|	ПартииНоменклатурыОстатки.Партия КАК Партия,
	|	ЕСТЬNULL(ПартииНоменклатурыОстатки.КоличествоОстаток, 0) КАК КоличествоОстаток,
	|	ЕСТЬNULL(ПартииНоменклатурыОстатки.СуммаОстаток, 0) КАК СуммаОстаток
	|ИЗ
	|	ВТ_ТабЧасть КАК ВТ_ТабЧасть
	|		ЛЕВОЕ СОЕДИНЕНИЕ РегистрНакопления.ПартииНоменклатуры.Остатки(
	|				&МоментВремени,
	|				Номенклатура В
	|					(ВЫБРАТЬ
	|						Т.Номенклатура
	|					ИЗ
	|						ВТ_ТабЧасть КАК Т)) КАК ПартииНоменклатурыОстатки
	|		ПО ВТ_ТабЧасть.Номенклатура = ПартииНоменклатурыОстатки.Номенклатура
	|
	|УПОРЯДОЧИТЬ ПО
	|	ПартииНоменклатурыОстатки.Партия.МоментВремени" + ПорядокСортировкиПартий + "
	|ИТОГИ
	|	МАКСИМУМ(КоличествоВДокументе),
	|	СУММА(КоличествоОстаток)
	|ПО
	|	Номенклатура";
	
	Запрос.УстановитьПараметр("МоментВремени", МоментВремени());
	
	// Обход результатов запроса
	ВыборкаНоменклатура = Запрос.Выполнить().Выбрать(ОбходРезультатаЗапроса.ПоГруппировкам);	
	
	Пока ВыборкаНоменклатура.Следующий() Цикл
		// Контроль наличия номенклатуры
		Превышение = ВыборкаНоменклатура.КоличествоВДокументе - ВыборкаНоменклатура.КоличествоОстаток;
		Если Превышение > 0 Тогда 
			
			Сообщение = Новый СообщениеПользователю;
			Сообщение.Текст = СтрШаблон("Превышение остатка по номенклатуре %1 в количестве %2 (оперативный учет, регистр ""Партии номенклатуры"")", 
				ВыборкаНоменклатура.НоменклатураПредставление, Превышение);						
			Сообщение.Сообщить();
			
			Отказ = Истина;
		КонецЕсли;
		
		Если Отказ Тогда
			Продолжить;
		КонецЕсли;
		
		ОсталосьСписать = ВыборкаНоменклатура.КоличествоВДокументе;
		Выборка = ВыборкаНоменклатура.Выбрать();
		
		Пока Выборка.Следующий() и ОсталосьСписать <> 0 Цикл
			
			// Движение по регистру партии номенклатуры
			Списываем = Мин (ОсталосьСписать, Выборка.КоличествоОстаток);
			
			Движение = Движения.ПартииНоменклатуры.ДобавитьРасход();
			Движение.Период = Дата;
			Движение.Номенклатура = Выборка.Номенклатура;
			Движение.Партия = Выборка.Партия;
			
			Движение.Количество = Списываем;			
			Движение.Сумма = Списываем / Выборка.КоличествоОстаток * Выборка.СуммаОстаток;
			
			ОсталосьСписать = ОсталосьСписать - Списываем;
		КонецЦикла;
		
	КонецЦикла;	
	
КонецПроцедуры

Процедура ОбработкаПроведенияБУ (Отказ)

	// ДВИЖЕНИЯ ПО РЕГИСТРУ УПРАВЛЕНЧЕСКИЙ (СТАРАЯ МЕТОДИКА ПРОВЕДЕНИЯ)
	
	Движения.Управленческий.Записывать = Истина;
	Движения.Управленческий.Записать();
	
	// Установка блокировки данных в регистре Управленческий по списку номенклатур табличной части
	Блокировка = Новый БлокировкаДанных;
	ЭлементБлокировки = Блокировка.Добавить("РегистрБухгалтерии.Управленческий");
	ЭлементБлокировки.УстановитьЗначение("Счет", ПланыСчетов.Управленческий.Товары);
	ЭлементБлокировки.Режим = РежимБлокировкиДанных.Исключительный;
	ЭлементБлокировки.ИсточникДанных = СписокНоменклатуры;
	ЭлементБлокировки.ИспользоватьИзИсточникаДанных(ПланыВидовХарактеристик.ВидыСубконто.Номенклатура, "Номенклатура");
	Блокировка.Заблокировать();
	
	// Запрос получения данных для формирования движений
	Запрос = Новый Запрос;
	Запрос.Текст = 
	"ВЫБРАТЬ
	|	РасходнаяНакладнаяСписокНоменклатуры.Номенклатура КАК Номенклатура,
	|	СУММА(РасходнаяНакладнаяСписокНоменклатуры.Количество) КАК Количество,
	|	СУММА(РасходнаяНакладнаяСписокНоменклатуры.Сумма) КАК Сумма
	|ПОМЕСТИТЬ ВТ_ТабЧасть
	|ИЗ
	|	Документ.РасходнаяНакладная.СписокНоменклатуры КАК РасходнаяНакладнаяСписокНоменклатуры
	|ГДЕ
	|	РасходнаяНакладнаяСписокНоменклатуры.Ссылка = &Ссылка
	|
	|СГРУППИРОВАТЬ ПО
	|	РасходнаяНакладнаяСписокНоменклатуры.Номенклатура
	|
	|ИНДЕКСИРОВАТЬ ПО
	|	Номенклатура
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|ВЫБРАТЬ
	|	ВТ_ТабЧасть.Номенклатура КАК Номенклатура,
	|	ВТ_ТабЧасть.Номенклатура.Представление КАК НоменклатураПредставление,
	|	ВТ_ТабЧасть.Количество КАК КоличествоВДокументе,
	|	УправленческийОстаткиПоНоменклатуреИСрокам.Субконто2 КАК СрокГодности,
	|	ЕСТЬNULL(УправленческийОстаткиПоНоменклатуреИСрокам.КоличествоОстаток, 0) КАК КоличествоОстаток,
	|	ЕСТЬNULL(УправленческийОстаткиПоНоменклатуре.СуммаОстаток, 0) КАК СуммаОстаток
	|ИЗ
	|	ВТ_ТабЧасть КАК ВТ_ТабЧасть
	|		ЛЕВОЕ СОЕДИНЕНИЕ РегистрБухгалтерии.Управленческий.Остатки(
	|				&МоментВремени,
	|				Счет = &СчетТовары,
	|				&СубконтоНоменклатура,
	|				Субконто1 В
	|					(ВЫБРАТЬ
	|						Т.Номенклатура
	|					ИЗ
	|						ВТ_ТабЧасть КАК Т)) КАК УправленческийОстаткиПоНоменклатуре
	|		ПО ВТ_ТабЧасть.Номенклатура = УправленческийОстаткиПоНоменклатуре.Субконто1
	|		ЛЕВОЕ СОЕДИНЕНИЕ РегистрБухгалтерии.Управленческий.Остатки(
	|				&МоментВремени,
	|				Счет = &СчетТовары,
	|				&СубконтоНоменклатураСрок,
	|				Субконто1 В
	|					(ВЫБРАТЬ
	|						Т.Номенклатура
	|					ИЗ
	|						ВТ_ТабЧасть КАК Т)) КАК УправленческийОстаткиПоНоменклатуреИСрокам
	|		ПО ВТ_ТабЧасть.Номенклатура = УправленческийОстаткиПоНоменклатуреИСрокам.Субконто1
	|
	|УПОРЯДОЧИТЬ ПО
	|	СрокГодности
	|ИТОГИ
	|	МАКСИМУМ(КоличествоВДокументе),
	|	СУММА(КоличествоОстаток),
	|	МАКСИМУМ(СуммаОстаток)
	|ПО
	|	Номенклатура";
	
	СубконтоНоменклатура = Новый Массив(1);
	СубконтоНоменклатура[0] = ПланыВидовХарактеристик.ВидыСубконто.Номенклатура;
	
	СубконтоНоменклатураСрок = Новый Массив(2);
	СубконтоНоменклатураСрок[0] = ПланыВидовХарактеристик.ВидыСубконто.Номенклатура;
	СубконтоНоменклатураСрок[1] = ПланыВидовХарактеристик.ВидыСубконто.СрокиГодности;  
	
	Запрос.УстановитьПараметр("Ссылка", Ссылка);
	Запрос.УстановитьПараметр("МоментВремени", МоментВремени());
	Запрос.УстановитьПараметр("СчетТовары", ПланыСчетов.Управленческий.Товары);
	Запрос.УстановитьПараметр("СубконтоНоменклатура", СубконтоНоменклатура);
	Запрос.УстановитьПараметр("СубконтоНоменклатураСрок", СубконтоНоменклатураСрок);
	
	// Обход результатов запроса
	ВыборкаНоменклатура = Запрос.Выполнить().Выбрать(ОбходРезультатаЗапроса.ПоГруппировкам);
	Пока ВыборкаНоменклатура.Следующий() Цикл
		
		// Контроль наличия номенклатуры
		Превышение = ВыборкаНоменклатура.КоличествоВДокументе - ВыборкаНоменклатура.КоличествоОстаток;
		Если Превышение > 0 Тогда
			Сообщение = Новый СообщениеПользователю;
			Сообщение.Текст = СтрШаблон("Превышение остатка по номенклатуре %1 в количестве %2 (бухгалтерский учет)", 
				ВыборкаНоменклатура.НоменклатураПредставление, Превышение);						                      
			Сообщение.Сообщить();
			
			Отказ = Истина;
		КонецЕсли;
		
		Если Отказ Тогда 
			Продолжить;
		КонецЕсли;
		
		ОсталосьСписать = ВыборкаНоменклатура.КоличествоВДокументе;
		
		СуммаПоНоменклатуре = ВыборкаНоменклатура.СуммаОстаток;
		КоличествоПоНоменклатуре = ВыборкаНоменклатура.КоличествоОстаток;
		
		// с помощью этих переменных будем контролировать, чтобы при списании всего количества по номенклатуре, 
		// суммовой остаток также был списан полностью
		КоличественныйОстатокПоНоменклатуре = ВыборкаНоменклатура.КоличествоОстаток;		
		СуммовойОстатокПоНоменклатуре = ВыборкаНоменклатура.СуммаОстаток;
		
		Выборка = ВыборкаНоменклатура.Выбрать();
		Пока Выборка.Следующий() И ОсталосьСписать <> 0 Цикл
			
			// Проводка отражения списания товара
			КоличествоСписываем = Мин (Выборка.КоличествоОстаток, ОсталосьСписать);
			
			Проводка = Движения.Управленческий.Добавить();
			
			Проводка.Период = Дата;
			Проводка.СчетДт = ПланыСчетов.Управленческий.ПрибылиУбытки;
			Проводка.СчетКт = ПланыСчетов.Управленческий.Товары;
			Проводка.СубконтоКт[ПланыВидовХарактеристик.ВидыСубконто.Номенклатура] = Выборка.Номенклатура;				 
			Проводка.СубконтоКт[ПланыВидовХарактеристик.ВидыСубконто.СрокиГодности] = Выборка.СрокГодности;				 
			
			Проводка.КоличествоКт = КоличествоСписываем;			
			Если КоличествоСписываем = КоличественныйОстатокПоНоменклатуре Тогда
				СуммаСписываем = СуммовойОстатокПоНоменклатуре;
			Иначе
				СуммаСписываем = КоличествоСписываем / КоличествоПоНоменклатуре * СуммаПоНоменклатуре;
			КонецЕсли;			
			Проводка.Сумма = СуммаСписываем;
			
			КоличественныйОстатокПоНоменклатуре = КоличественныйОстатокПоНоменклатуре - КоличествоСписываем;
			СуммовойОстатокПоНоменклатуре = СуммовойОстатокПоНоменклатуре - Проводка.Сумма;		
			
			ОсталосьСписать = ОсталосьСписать - КоличествоСписываем;             
			
		КонецЦикла;                          
	КонецЦикла;
	
	// Проводка отражения продажи товара
	Проводка = Движения.Управленческий.Добавить();
	Проводка.Период = Дата;
	Проводка.СчетДт = ПланыСчетов.Управленческий.Покупатели;
	Проводка.СчетКт = ПланыСчетов.Управленческий.ПрибылиУбытки;
	Проводка.Сумма = СуммаПоДокументу;
	
КонецПроцедуры

