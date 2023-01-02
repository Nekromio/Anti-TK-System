# Anti-TK-System
Anti-TK System

# en
We bring to your attention an Anti-TK System that allows you to track non-conscientious players who kill/injure teammates (with mp_friendlyfire 1). This plugin provides the functionality:

1. If a player attacks an ally in the first seconds at the start of the round, he is instantly killed, the number of seconds is configured in the plugin config

2. Allows the victim to choose a punishment for the offender, if the target is dead, the punishment will take effect at the next resurrection of the killer

3. The plugin has a "Mirror damage", which returns the damage inflicted on an ally in % ratio, with the ability to disable this function in the config

3.1. "Screen shaking" - When the damage is done, the screen is shaking, where the strength and activity can be configured in the plugin config

3.2. "Pulling the sight" - When the damage is done, it pulls the sight, the strength of which can also be adjusted from 0 to 180 degrees and, of course, with the ability to turn off this function

4. Has a "good behavior" tracking system, if a player has punishment points, then after N (configurable) number of rounds they are taken away one by one

5. Provides a large selection of punishments, with the ability to enable/disable any of them in the plugin config

6. Allows you to kick / ban players without the participation of the administrator for killing their

7. The plugin has a new syntax, it is written in a new style

8. The plugin has translation files, for each game its own: Css v.34/Css OB/ CsGo

9. The plugin itself determines which game it is running on the server and, depending on this, applies the settings

10. The logging mode is displayed in a separate folder addons/sourcemod/logs/anti-tk/stk_log_DATA.log, if there is no such folder, the plugin will create it itself

11. In the configuration of the pagin, there is an option to choose a system of bans: Standard Ban, SourceBans Ban, MaterialAdmin Ban, or completely disable bans and make a regular Kick

12. In the types of punishments, there is also a "Transformation into a chicken", after the transformation, the "Chicken" has no opportunity to interact with the "World"

12.1. When punishing "Turning into a chicken", all weapons, all grenades, a knife and Zeus are removed from the player (if the game is csgo)

12.2. The "Chicken" does not have the "E" button, it will not be able to install or clear the bomb. He will also not be able to take out a hostage or pick up weapons

12.3. You can also set the speed of the "Chicken" in the plugin config, according to the standard, it is reduced by 15% so that players can catch up with it

13. Damage from a Molotov cocktail or a grenade is not taken into account, which corrects the situation when players specifically climb into the fire

13.1. Also, with damage from a Molotov cocktail or a grenade, the amount of damage does not go into the calculation of the "Damage limit for allies"

14. A system has been created for calculating the amount of damage done to your allies ("Damage limit on allies")

14.1. There is also a "Good Behavior" system, which allows you to reduce the amount of this damage if the player did not cause damage to his allies during one round

# ru
Мы предлагаем вашему вниманию систему защиты от ТЗ, которая позволяет отслеживать недобросовестных игроков, которые убивают/ранят товарищей по команде (с mp_friendlyfire 1). Этот плагин обеспечивает функциональность:

1. Если игрок атакует союзника в первые секунды в начале раунда, он мгновенно погибает, количество секунд настраивается в конфигурации плагина

2. Позволяет жертве выбрать наказание для преступника, если цель мертва, наказание вступит в силу при следующем воскрешении убийцы

3. В плагине есть "Зеркальный урон", который возвращает нанесенный союзнику урон в % соотношении, с возможностью отключить эту функцию в конфигурации

3.1. "Дрожание экрана" - когда нанесен урон, экран дрожит, где сила и активность могут быть настроены в конфигурации плагина.

3.2. "Вытягивание прицела" - когда нанесен урон, он вытягивает прицел, силу которого также можно регулировать от 0 до 180 градусов и, конечно же, с возможностью отключения этой функции

4. Имеет систему отслеживания "хорошего поведения", если у игрока есть штрафные очки, то после N (настраиваемого) количества раундов они отбираются один за другим

5. Предоставляет большой выбор наказаний, с возможностью включения/ отключения любого из них в конфигурации плагина

6. Позволяет кикать/банить игроков без участия администратора за убийство их

7. Плагин имеет новый синтаксис, он написан в новом стиле

8. В плагине есть файлы перевода, для каждой игры свои: Css v.34/Css OB/ CsGo

9. Плагин сам определяет, какая игра запущена на сервере, и, в зависимости от этого, применяет настройки

10. Режим ведения журнала отображается в отдельной папке addons/sourcemod/logs/anti-tk/stk_log_DATA.log, если такой папки нет, плагин создаст ее сам

11. В конфигурации страницы есть возможность выбрать систему банов: Стандартный бан, бан SourceBans, бан MaterialAdmin или полностью отключить баны и сделать обычный кик

12. В видах наказаний также присутствует "Превращение в курицу", после трансформации "Курица" не имеет возможности взаимодействовать с "Миром"

12.1. При наказании "Превращение в цыпленка" у игрока изымается все оружие, все гранаты, нож и Зевс (если игра csgo).

12.2. У "Цыпленка" нет кнопки "Е", он не сможет установить или обезвредить бомбу. Он также не сможет вывести заложника или забрать оружие

12.3. Вы также можете установить скорость "Цыпленка" в конфигурации плагина, согласно стандарту, она снижена на 15%, чтобы игроки могли ее догнать

13. Урон от коктейля Молотова или гранаты не учитывается, что исправляет ситуацию, когда игроки специально лезут в огонь

13.1. Также, при уроне от коктейля Молотова или гранаты, сумма урона не входит в расчет "Лимита урона для союзников".

14. Создана система для расчета суммы урона, нанесенного вашим союзникам ("Лимит урона союзникам")

14.1. Также существует система "Хорошего поведения", которая позволяет уменьшить размер этого урона, если игрок не нанес урона своим союзникам в течение одного раунда
