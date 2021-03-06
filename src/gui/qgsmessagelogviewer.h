/***************************************************************************
                          qgsmessagelogviewer.h  -  description
                             -------------------
    begin                : October 2011
    copyright            : (C) 2011 by Juergen E. Fischer
    email                : jef at norbit dot de
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
#ifndef QGSMESSAGELOGVIEWER_H
#define QGSMESSAGELOGVIEWER_H

#include <ui_qgsmessagelogviewer.h>
#include <qgisgui.h>
#include "qgsmessagelog.h"

#include <QString>
#include "qgis_gui.h"
#include "qgis.h"

class QStatusBar;
class QCloseEvent;

/** \ingroup gui
 * A generic dialog widget for displaying QGIS log messages.
 */
class GUI_EXPORT QgsMessageLogViewer: public QDialog, private Ui::QgsMessageLogViewer
{
    Q_OBJECT
  public:

    /**
     * Create a new message log viewer, it will automatically connect to the system's
     * QgsMessageLog::instance() singleton.
     */
    QgsMessageLogViewer( QStatusBar *statusBar = nullptr, QWidget *parent SIP_TRANSFERTHIS = nullptr, Qt::WindowFlags fl = QgisGui::ModalDialogFlags );
    // TODO QGIS 3.0: remove statusBar (it's unused)

  public slots:
    void logMessage( QString message, QString tag, QgsMessageLog::MessageLevel level );

  protected:
    void closeEvent( QCloseEvent *e ) override;
    void reject() override;

  private slots:
    void closeTab( int index );
};

#endif
