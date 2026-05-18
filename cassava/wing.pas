{ Authors: 
- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global 
	(Center for Analysis of Sustainable Agriculture Systems) 
	<casas.kensington gmail.com>
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e 
	lo sviluppo economico sostenibile / CASAS Global) <quartese gmail.com>

Copyright: (C) CASAS Global (Center for the Analysis of Sustainable 
	Agricultural Systems)

SPDX-License-Identifier: GPL-3.0-or-later }

$STORAGE:2
	SUBROUTINE LACE(KAPH,HAY)
C CHRYSOPA CARNEA --Green lacewing
C HAY -- HAY=3 = alfalfa was cut, HAY=2 = frost
	COMMON/APHDD/DDAP,DDAB,DDAS,DDAA,DDAH,DDAW,DDAX,DDAEV
	COMMON/APHNUM/PN(5),BN(5),SN(5),HN(4),WN(4),AN(3),EVN(3),TN(3)
	COMMON/APHPOP/P(5),B(5),S(5),H(4),W(4),A(3),EV(3),T(3)
	COMMON/BDEMAN/BP,BB,BH,BE,BW
	COMMON/IMMIGR/FIMP,FIMB,FIMS,FIMA,FIMT,FIMH,FIMW,FIMEV
	COMMON/LWCOM/WAGE(5),WR(60),WRN(60),VLW(60,4),
     .  BETAW,AVGLW(4),SDW(7),FMORTW,DELMAX
	COMMON/SUPPLY/NH(4),NP(5),NB(5),NS(5),NW(6),NA(5),EVNA(5),
     .	NTX(5),TOTNA,TOTEVNA,TOTTXNA
	COMMON/ZEROS/ZEROS(60)
 
	INTEGER HAY
	REAL NP,NS,NH,NW,NWA,NB,NA,NTX

	DELK=WAGE(5)/KAPH

C************* Immigration***************************
C KYA= cell in R array of young adults
C FIMP = number immigrating per day (INFILE)
	KYA=WAGE(4)/WAGE(5)*KAPH+1
	WIMM=FIMW/DELK
	WRN(KYA)=WRN(KYA)+WIMM
	WR(KYA)=WR(KYA)+WIMM*AVGLW(4)

C How much they eat
C Q = mass of attackers in stages 2,3,4
C NWA = total mass of aphids attacked by stages 2,3,4
	NWA=NW(2)
 
C 7 day average for SUPL/DEM
	IF(NWA .GT. 0.)THEN
		DO 3 I=7, 2, -1
3		SDW(I)=SDW(I-1)
		IF(DEM.GT.0.)SDW(1)=NWA/DEMW
	ENDIF
	ASD=SUM(SDW,7)/7.

C Reproduction
	EGGS=0.
	FEMS=0.5
	ADLTF=ZERONE(ALOG( SUM(PN,5)+SUM(BN,5)+AN(1) )/7.901)

C IAD = index of youngest adult
	JAD = 1 + WAGE(4)/DELK
	DELADL =WAGE(5)-WAGE(4)
	DO 5 J=1,KAPH
		IF(VLW(J,4).GT.0.)THEN
C	FF= # adlts in jth cell
			FF = DELK * VLW(J,4)*WRN(J)
C	ALDONE = dd of adult development completed
			ALDONE = DELADL * (J-JAD)/(KAPH-JAD)
C   OVIP is max for youngest adults, decreases linearly
			OVIP = AMAX1( 1.9 * ADLTF - 0.0019 * ALDONE , 0.)
			EGGS = EGGS + OVIP * FF
		ENDIF
5	CONTINUE
	REPRON = EGGS * FEMS
	REPRO =  .1*REPRON

C******* COMPUTE IMMATURE GROWTH************************

C Mortalities for each lifestage.
	DO 10 I=1,4

C Intrinsic and S/D mortalities
		IF(I.LE.2 .AND. HAY.EQ.3)AMORT=.8
		IF(HAY.EQ.2)AMORT=.95

c  Check out migration and dwt for nums and mass ............
C Migration
		AMIG=0.
		IF (I.EQ.4) AMIG=ASD
	IF(I.EQ.2) THEN 
		DO 11 J=1,KAPH
			IF(VLW(J,2).GT.0.)DMGROW = DMGROW + 
     .          WRN(J)*VLW(J,2)*.03085*.1*EXP(.03085*J*DELK)*SDW(1)
11		CONTINUE
	ENDIF
10	CONTINUE


	CALL DEL2(REPRO,  X,TSHED,WR,  ZEROS,WAGE(5),KAPH,DDAW)
	CALL DEL2(REPRON, X,TSHED,WRN ,ZEROS,WAGE(5),KAPH,DDAW)

	DO 15 I=1,4
		W(I)  = VDOT(WR, VLW(1,I),KAPH) * DELK
		WN(I) = VDOT(WRN,VLW(1,I),KAPH) * DELK
15	CONTINUE
	RETURN
	END
