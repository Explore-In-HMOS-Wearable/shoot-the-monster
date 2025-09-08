import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import display from '@ohos.display';

@Entry
@Component
struct Index {
  @State accelX: string = '0.000';
  @State accelY: string = '0.000';
  @State accelZ: string = '0.000';
  @State gyroX: string = '0.000';
  @State gyroY: string = '0.000';
  @State gyroZ: string = '0.000';
  @State isMonitoring: boolean = false;

  @State cursorX: number = 111.5;
  @State cursorY: number = 111.5;
  @State circleColor: Color = Color.Red;
  @State score: number = 0;
  @State monsterX: number = 0;
  @State monsterY: number = 0;
  @State monsterVisible: boolean = false;
  @State monsterSize: number = 30;

  private circleDiameter: number = 0
  private circleRadius: number = 0
  private circleCenterX: number = 0
  private circleCenterY: number = 0
  private dotRadius: number = 7.5;
  private sensitivity: number = 2;
  private edgeThreshold: number = 10;

  aboutToAppear(): void {
    this.circleDiameter = display.getDefaultDisplaySync().width/2
    this.circleRadius = this.circleDiameter / 2;
    this.circleCenterX = this.circleRadius;
    this.circleCenterY = this.circleRadius;
    this.cursorX = this.circleCenterX - this.dotRadius;
    this.cursorY = this.circleCenterY - this.dotRadius;
    this.spawnMonster();
    this.startSensors()
  }

  aboutToDisappear(): void {
    this.stopSensors()
  }

  private spawnMonster(): void {
    const minDistance = 40;
    const maxDistance = this.circleRadius - this.monsterSize - 10;

    const getRandom = (): number => {
      return new Date().getTime() % 10000 / 10000;
    };

    const angle = getRandom() * Math.PI * 2;
    const distance = minDistance + (getRandom() * (maxDistance - minDistance));

    this.monsterX = this.circleCenterX + Math.cos(angle) * distance - this.monsterSize / 2;
    this.monsterY = this.circleCenterY + Math.sin(angle) * distance - this.monsterSize / 2;
    this.monsterVisible = true;
  }

  private checkMonsterHit(): boolean {
    if (!this.monsterVisible) return false;

    const cursorCenterX = this.cursorX + this.dotRadius;
    const cursorCenterY = this.cursorY + this.dotRadius;
    const monsterCenterX = this.monsterX + this.monsterSize/2;
    const monsterCenterY = this.monsterY + this.monsterSize/2;

    const distance = Math.sqrt(
      Math.pow(cursorCenterX - monsterCenterX, 2) +
      Math.pow(cursorCenterY - monsterCenterY, 2)
    );

    return distance < (this.dotRadius + this.monsterSize/2);
  }

  private startSensors(): void {
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        this.accelX = data.x.toFixed(3);
        this.accelY = data.y.toFixed(3);
        this.accelZ = data.z.toFixed(3);

        this.updateCursorPosition(data.x, data.y);
      }, { interval: 10000000 });

      sensor.on(sensor.SensorId.GYROSCOPE, (data: sensor.GyroscopeResponse) => {
        this.gyroX = data.x.toFixed(3);
        this.gyroY = data.y.toFixed(3);
        this.gyroZ = data.z.toFixed(3);
      }, { interval: 10000000 });

      this.isMonitoring = true;
      promptAction.showToast({ message: 'Go!', duration: 1000 });
    } catch (error) {
      const e: BusinessError = error as BusinessError;
      console.error(`Failed to start sensors. Code: ${e.code}, message: ${e.message}`);
      promptAction.showToast({ message: `Error: ${e.code}`, duration: 2000 });
    }
  }

  private updateCursorPosition(accelX: number, accelY: number): void {
    let newX = this.cursorX + (-accelX * this.sensitivity);
    let newY = this.cursorY + (accelY * this.sensitivity);

    const distanceFromCenter = Math.sqrt(
      Math.pow(newX + this.dotRadius - this.circleCenterX, 2) +
      Math.pow(newY + this.dotRadius - this.circleCenterY, 2)
    );

    if (distanceFromCenter > this.circleRadius - this.dotRadius) {
      const angle = Math.atan2(
        newY + this.dotRadius - this.circleCenterY,
        newX + this.dotRadius - this.circleCenterX
      );

      newX = this.circleCenterX + Math.cos(angle) * (this.circleRadius - this.dotRadius) - this.dotRadius;
      newY = this.circleCenterY + Math.sin(angle) * (this.circleRadius - this.dotRadius) - this.dotRadius;
    }

    this.checkEdgeProximity(distanceFromCenter);
    this.cursorX = newX;
    this.cursorY = newY;
  }

  private checkEdgeProximity(distanceFromCenter: number): void {
    const distanceToEdge = this.circleRadius - distanceFromCenter;
    if (distanceToEdge <= this.edgeThreshold) {
      this.circleColor = Color.Blue;
      this.stopSensors();
      promptAction.showToast({
        message: `You Died! Score: ${this.score}`,
        duration: 3000,
        bottom: '50%'
      });
      setTimeout(() => {
        this.restartGame();
      }, 3000);
    } else {
      this.circleColor = Color.Red;
    }
  }

  private restartGame(): void {
    this.score = 0;
    this.cursorX = this.circleCenterX - this.dotRadius;
    this.cursorY = this.circleCenterY - this.dotRadius;
    this.monsterVisible = false;
    this.spawnMonster();
    this.circleColor = Color.Red;
    this.startSensors();

    promptAction.showToast({
      message: 'Get Ready!',
      duration: 1000
    });
  }

  private stopSensors(): void {
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
      sensor.off(sensor.SensorId.GYROSCOPE);
      this.isMonitoring = false;
    } catch (error) {
      const e: BusinessError = error as BusinessError;
      console.error(`Failed to stop sensors. Code: ${e.code}, message: ${e.message}`);
    }
  }

  private showPosition(): void {
    if (this.monsterVisible && this.checkMonsterHit()) {
      this.score += 10;
      this.monsterVisible = false;
      promptAction.showToast({
        message: `Nice! +10 : ${this.score}`,
        duration: 1500
      });

      setTimeout(() => {
        this.spawnMonster();
      }, 1000);
    } else {
      const positionText = `X: ${this.cursorX.toFixed(1)}, Y: ${this.cursorY.toFixed(1)}`;
      promptAction.showToast({
        message: positionText,
        duration: 1000,
        bottom: '50%'
      });
    }
  }

  build() {
    Stack() {
      Circle()
        .width(this.circleDiameter)
        .height(this.circleDiameter)
        .fill(Color.Transparent)
        .stroke(this.circleColor)
        .strokeWidth(3)

      if (this.monsterVisible) {
        Image($r('app.media.monster'))
          .width(this.monsterSize)
          .height(this.monsterSize)
          .position({ x: this.monsterX, y: this.monsterY })
          .objectFit(ImageFit.Contain)
      }

      Circle()
        .width(10)
        .height(10)
        .position({ x: this.cursorX, y: this.cursorY })
        .fill(Color.Red)
        .opacity(0.8)

    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .onClick(() => {
      this.showPosition();
    })
  }
}